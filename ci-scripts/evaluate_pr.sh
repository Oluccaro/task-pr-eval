#!/bin/bash

set -e

# Load environment variables
repo="$GITHUB_REPOSITORY"
openai_api_key="$OPENAI_API_KEY"
monday_api_key="$MONDAY_API_KEY"
github_token="$GITHUB_TOKEN"
pr_body="$PR_BODY"
pr_title="$PR_TITLE"

echo "Extracting the task id"

function extract_task_hash {
        grep --only-matching --perl-regexp '(?<=\[[tm][:-])[a-zA-Z0-9]+(?=\])'
}

function get_pull_request_title {
    gh pr view "$PR_NUMBER" --json title --jq '.title'
}

TASK_ID="$(get_pull_request_title | extract_task_hash )"

if ! [[ -n $TASK_ID ]]; then
    echo "no task_id found on the pr title"
    exit
fi

echo "task id => $TASK_ID"

# Function to fetch Monday.com card
echo "Fetching Monday.com card... $TASK_ID"

monday_description=$(curl -s -X POST https://api.monday.com/v2 \
    -H "Authorization: Bearer $monday_api_key " \
    -H "Content-Type: application/json" \
    --data "{\"query\":\"{ items (ids: $TASK_ID) { name column_values (ids: [\\\"long_text_mkpgqs8k\\\"]){ id text } } }\"}" \
    | jq -r ".data.items[] | .column_values[0].text"
    )

if [ -z "$monday_description" ]; then
    echo "No matching Monday.com card found. Exiting."
    exit 1
fi

# Create summarizing payload
monday_description=$(echo $monday_description | jq -Rs .)
summarize_payload=$(mktemp)
echo $monday_description
echo "{
        \"model\": \"gpt-4o-mini\",
        \"instructions\": \"You're receiving a description of a task. Summarize in 2-3 sentences:\",
        \"input\": $monday_description
    }" > $summarize_payload


echo "Summarizing Monday.com card..."

summarized_description=$(curl -s -X POST https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $openai_api_key " \
    -H "Content-Type: application/json" \
    --data @"$summarize_payload" \
    | jq -r ".output[0].content[0].text"
)
echo $summarized_description

if [ -z "$summarized_description" ]; then
    echo "Error summarizing description"
    exit 1
fi

# Fetch existing comments
existing_comments=$(gh pr view "$PR_NUMBER" --json comments --jq '.comments[].body')

# Check if a summary is already posted
if echo "$existing_comments" | grep -q "📌 Monday Task Summary"; then
    echo "✅ Summary already posted. Skipping..."
else 
    gh pr comment  "$PR_NUMBER" \
    --body "$(echo -e "### 📌 Monday Task Summary:\n\n$summarized_description\n\n---\n✅ Automated comment from GitHub Action Using ChatGPT")"
    > /dev/null
    echo 'Comment with summary of card description to pull request'
fi

pr_diff=$(mktemp)
# Creating PR coherence payload
gh pr diff "$PR_NUMBER" | jq -Rs .> $pr_diff

pr_coherence_payload=$(mktemp)
input=$(mktemp)

echo -e "task description: $monday_description PR diff: $(cat $pr_diff)" > $input

echo "{
        \"model\": \"gpt-4o\",
        \"temperature\": 0,
        \"instructions\": \"You'll receive the task description and the PR content diff. n\nClassify the PR as:\n- OK: If it matches the task\n- ALERT: If the main idea is related but have some inconsistency like altering thing out of the scope \n- NOK: If it's unrelated, the requests misses the main point of the task \n. Also provide a brief explanation for your classification.\",
        \"input\": [
            { \"type\": \"message\", \"role\": \"user\", \"content\": $monday_description },
            { \"type\": \"message\", \"role\": \"user\", \"content\": $(cat $pr_diff) } 
        ]
    }" > $pr_coherence_payload
cat $pr_coherence_payload

echo "Evaluating PR coherence..."
evaluation=$(curl -s -X POST https://api.openai.com/v1/responses \
    -H "Authorization: Bearer $openai_api_key " \
    -H "Content-Type: application/json" \
    --data @"$pr_coherence_payload"
    jq -r ".output[0].content[0].text"
)

if ! [[ -n $evaluation ]] ; then
    echo "PR coherence evaluation didn't work" 
    exit
fi

classification=$(echo "$evaluation" | sed -n 's/.*\*\*Classification: \([A-Z]*\)\*\*.*$/\1/p')
explanation=$(echo "$evaluation" | sed -n 's/.*\*\*Explanation:\s*//p' | tr -d '\n')
echo "CLASS $classification |"
echo "EXPLANATION $explanation "

# Determine label name and color
case $classification in
    "OK")
        label_name="monday_description_ok"
        remove_label_1="monday_description_alert"
        remove_label_2="monday_description_not_ok"
        ;;
    "ALERT")
        label_name="monday_description_alert"
        remove_label_1="monday_description_ok"
        remove_label_2="monday_description_not_ok"
        ;;
    "NOK")
        label_name="monday_description_not_ok"
        remove_label_1="monday_description_alert"
        remove_label_2="monday_description_ok"
        ;;
esac

echo $label_name
# Create or update label

gh pr edit "$PR_NUMBER" --remove-label "$remove_label_1" > /dev/null
gh pr edit "$PR_NUMBER" --remove-label "$remove_label_2" > /dev/null

gh pr edit "$PR_NUMBER" --add-label "$label_name" > /dev/null
echo "Pull requests labelled as $label_name."

comment_id=$(gh pr view "$PR_NUMBER" --json comments \
  | jq -r '.comments[] | select(.author.login=="github-actions") | select(.body | contains("### 🚨 PR Evaluation")) | .id' | tail -n 1)


# Post the new PR evaluation comment
echo "Posting new PR evaluation comment..."

echo -e "### 🚨 PR Evaluation:
**Classification:** $classification

**Explanation:** $explanation

---  
✅ Automated comment from GitHub Action Using ChatGPT"
