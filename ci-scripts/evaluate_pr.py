import os
import requests
import openai
import json
from github import Github

def fetch_monday_card(api_key, pr_title):
    """Fetch the corresponding Monday.com card based on the PR title."""
    query = """
    { boards (limit: 1) { items (limit: 10) { name column_values { text } } } }
    """
    response = requests.post(
        "https://api.monday.com/v2",
        headers={"Authorization": api_key, "Content-Type": "application/json"},
        json={"query": query},
    )
    data = response.json()
    for item in data["data"]["boards"][0]["items"]:
        if pr_title.lower() in item["name"].lower():
            return item["column_values"][0]["text"]  # Assuming first column is description
    return None

def summarize_description(api_key, description):
    """Summarize the Monday.com card description using OpenAI."""
    prompt = f"""
    Summarize the following task description in 2-3 sentences:
    {description}
    """
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role": "system", "content": "You are a helpful assistant."},
                  {"role": "user", "content": prompt}],
        api_key=api_key
    )
    return response["choices"][0]["message"]["content"].strip()

def evaluate_coherence(api_key, summary, pr_body):
    """Evaluate if the PR description aligns with the Monday.com summary."""
    prompt = f"""
    Compare the following:
    Task Summary: {summary}
    PR Description: {pr_body}
    
    Classify the PR as:
    - OK: If it matches the task
    - ALERT: If it's somewhat related but unclear
    - NOK: If it's unrelated
    Provide a brief explanation for your classification.
    """
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{"role": "system", "content": "You are an AI reviewing PR coherence."},
                  {"role": "user", "content": prompt}],
        api_key=api_key
    )
    return response["choices"][0]["message"]["content"].strip()

def post_github_comment(token, pr_number, repo, comment):
    """Post the evaluation result as a comment on GitHub PR."""
    g = Github(token)
    repo = g.get_repo(repo)
    pr = repo.get_pull(pr_number)
    pr.create_issue_comment(comment)

if __name__ == "__main__":
    repo = os.getenv("GITHUB_REPOSITORY")
    pr_number = os.getenv("GITHUB_REF").split("/")[-1]
    openai_api_key = os.getenv("OPENAI_API_KEY")
    monday_api_key = os.getenv("MONDAY_API_KEY")
    github_token = os.getenv("GITHUB_TOKEN")
    pr_body = os.getenv("PR_BODY")
    pr_title = os.getenv("PR_TITLE")

    monday_description = fetch_monday_card(monday_api_key, pr_title)
    if not monday_description:
        exit("No matching Monday.com card found.")

    summary = summarize_description(openai_api_key, monday_description)
    evaluation = evaluate_coherence(openai_api_key, summary, pr_body)

    comment = f"**Task Summary:** {summary}\n\n**Evaluation:** {evaluation}"
    post_github_comment(github_token, int(pr_number), repo, comment)
