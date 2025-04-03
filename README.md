# GitHub Action: Monday.com Task Validation with ChatGPT

## Overview
This GitHub Action automates the validation of pull requests (PRs) by comparing them with related tasks from Monday.com. It utilizes OpenAI's GPT API to:

1. Extract the task ID from the PR title.
2. Fetch the corresponding task description from Monday.com.
3. Summarize the task description using ChatGPT.
4. Post the summary as a comment on the PR.
5. Evaluate if the PR changes align with the task description.
6. Classify the PR as **OK**, **ALERT**, or **NOK** based on relevance.
7. Post an evaluation comment and apply corresponding labels.

## Implementation Details

### Extracting Task ID
- The script extracts a task ID from the PR title using regex (`[t:-]TASK_ID`).
- If no valid task ID is found, the script exits.

### Fetching Monday.com Task Description
- The task ID is used to query Monday.com’s API for the task details.
- If no task is found, the script exits.

### Summarizing the Task Description
- The task description is sent to OpenAI's API with a prompt to generate a concise summary.
- The summary is posted as a comment on the PR.

### Evaluating PR Coherence
- The script retrieves the PR’s diff (changes) and sends both the summarized task description and PR diff to OpenAI’s API.
- ChatGPT evaluates whether the changes align with the task and classifies them as:
  - **OK**: Matches the task.
  - **ALERT**: Some inconsistencies or scope creep.
  - **NOK**: Unrelated to the task.
- An explanation is provided alongside the classification.

### Applying Labels and Posting Evaluation
- Based on the classification, the script:
  - Removes existing labels.
  - Adds a new label (`monday_description_ok`, `monday_description_alert`, `monday_description_not_ok`).
- Posts an evaluation comment on the PR with the classification and explanation.

## Usage
### Environment Variables
This script requires the following environment variables:

- `OPENAI_API_KEY`: API key for OpenAI.
- `MONDAY_API_KEY`: API key for Monday.com.
- `GITHUB_TOKEN`: Token for GitHub API.

### Running the Script
This script is triggered automatically on PR events (e.g., opened, synchronized, reopened). It can also be executed manually by running:

```bash
./evaluate_pr.sh
```

## Outputs
- A summarized task description posted as a comment.
- A classification comment with an explanation.
- An appropriate label added to the PR.

## Example Output in PR Comments
**Task Summary:**
```
This task is about refactoring authentication logic to improve security and maintainability.
```

**PR Evaluation:**
```
Classification: ALERT
Explanation: The PR modifies authentication logic but also changes unrelated database models.
```

✅ Automated comment from GitHub Action Using ChatGPT

