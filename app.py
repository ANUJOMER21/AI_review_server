from flask import Flask, request, jsonify
import os
import logging
import asyncio
from functools import wraps
import json
from datetime import datetime
import hmac
import hashlib
from ai_reviewer import EnhancedAIReviewer

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
ANTHROPIC_API_KEY = os.environ.get('ANTHROPIC_API_KEY')
GITHUB_WEBHOOK_SECRET = os.environ.get('GITHUB_WEBHOOK_SECRET')
ALLOWED_REPOS = os.environ.get('ALLOWED_REPOS', '').split(',') if os.environ.get('ALLOWED_REPOS') else []

if not ANTHROPIC_API_KEY:
    raise ValueError("ANTHROPIC_API_KEY environment variable is required")

# Initialize AI Reviewer
ai_reviewer = EnhancedAIReviewer(ANTHROPIC_API_KEY)


def verify_github_signature(payload_body, signature_header):
    """Verify GitHub webhook signature"""
    if not GITHUB_WEBHOOK_SECRET:
        return True  # Skip verification if no secret is set

    if not signature_header:
        return False

    expected_signature = 'sha256=' + hmac.new(
        GITHUB_WEBHOOK_SECRET.encode('utf-8'),
        payload_body,
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(expected_signature, signature_header)


def async_route(f):
    """Decorator to handle async routes in Flask"""

    @wraps(f)
    def wrapper(*args, **kwargs):
        return asyncio.run(f(*args, **kwargs))

    return wrapper


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'ai-code-reviewer'
    })


@app.route('/webhook/github', methods=['POST'])
@async_route
async def github_webhook():
    """Handle GitHub webhook for pull requests"""
    try:
        # Verify signature
        signature = request.headers.get('X-Hub-Signature-256')
        if not verify_github_signature(request.data, signature):
            logger.warning("Invalid GitHub webhook signature")
            return jsonify({'error': 'Invalid signature'}), 401

        payload = request.get_json()

        # Only process pull request events
        if payload.get('action') not in ['opened', 'synchronize', 'reopened']:
            return jsonify({'message': 'Event ignored'}), 200

        # Check if repository is allowed
        repo_full_name = payload['repository']['full_name']
        if ALLOWED_REPOS and repo_full_name not in ALLOWED_REPOS:
            logger.warning(f"Repository {repo_full_name} not in allowed list")
            return jsonify({'error': 'Repository not allowed'}), 403

        # Extract PR information
        pr_data = payload['pull_request']
        pr_number = pr_data['number']
        pr_title = pr_data['title']
        pr_body = pr_data.get('body', '')

        # Get changed files (this would need GitHub API call in real implementation)
        # For now, we'll create a placeholder
        files = await get_pr_files(payload['repository'], pr_number)

        # Generate AI review
        review_result = await ai_reviewer.generate_review_async(
            pr_title=pr_title,
            pr_body=pr_body,
            files=files
        )

        # Generate markdown report
        markdown_report = generate_markdown_report(review_result, pr_data)

        # Return the review result
        return jsonify({
            'success': True,
            'pr_number': pr_number,
            'repository': repo_full_name,
            'review': {
                'security_score': review_result.security_score,
                'quality_score': review_result.quality_score,
                'approval': review_result.approval,
                'confidence': review_result.ai_confidence,
                'vulnerabilities_count': len(review_result.vulnerabilities),
                'issues_count': len(review_result.issues)
            },
            'markdown_report': markdown_report,
            'timestamp': datetime.utcnow().isoformat()
        })

    except Exception as e:
        logger.error(f"Error processing webhook: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500


@app.route('/review', methods=['POST'])
@async_route
async def manual_review():
    """Manual review endpoint for testing"""
    try:
        data = request.get_json()

        required_fields = ['pr_title', 'pr_body', 'files']
        if not all(field in data for field in required_fields):
            return jsonify({
                'error': 'Missing required fields',
                'required': required_fields
            }), 400

        # Generate AI review
        review_result = await ai_reviewer.generate_review_async(
            pr_title=data['pr_title'],
            pr_body=data['pr_body'],
            files=data['files'],
            user_preferences=data.get('preferences', {})
        )

        # Generate markdown report
        markdown_report = generate_markdown_report(review_result, {
            'title': data['pr_title'],
            'number': data.get('pr_number', 'manual'),
            'html_url': data.get('pr_url', '#')
        })

        return jsonify({
            'success': True,
            'review': {
                'security_score': review_result.security_score,
                'quality_score': review_result.quality_score,
                'approval': review_result.approval,
                'confidence': review_result.ai_confidence,
                'summary': review_result.summary,
                'vulnerabilities': [vars(v) for v in review_result.vulnerabilities],
                'issues': [vars(i) for i in review_result.issues],
                'recommendations': review_result.recommendations
            },
            'markdown_report': markdown_report,
            'timestamp': datetime.utcnow().isoformat()
        })

    except Exception as e:
        logger.error(f"Error in manual review: {e}")
        return jsonify({
            'error': 'Internal server error',
            'message': str(e)
        }), 500


async def get_pr_files(repository, pr_number):
    """
    Get PR files from GitHub API
    This is a placeholder - you'll need to implement GitHub API calls
    """
    # TODO: Implement actual GitHub API call
    # For now, return placeholder data
    return [
        {
            'filename': 'example.py',
            'status': 'modified',
            'additions': 10,
            'deletions': 5,
            'changes': 15,
            'patch': '+def new_function():\n+    return "hello"\n-# old comment',
            'file_type': 'python'
        }
    ]


def generate_markdown_report(review_result, pr_data):
    """Generate markdown report from review result"""
    report_lines = [
        f"# 🤖 AI Code Review Report",
        f"",
        f"**PR:** {pr_data.get('title', 'N/A')} (#{pr_data.get('number', 'N/A')})",
        f"**Generated:** {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC",
        f"**AI Confidence:** {review_result.ai_confidence:.1%}",
        f"",
        f"## 📊 Scores",
        f"",
        f"| Metric | Score | Status |",
        f"|--------|-------|--------|",
        f"| Security | {review_result.security_score}/100 | {get_score_emoji(review_result.security_score)} |",
        f"| Quality | {review_result.quality_score}/100 | {get_score_emoji(review_result.quality_score)} |",
        f"",
        f"## 🎯 Recommendation: **{review_result.approval}**",
        f"",
    ]

    # Add summary
    if review_result.summary:
        report_lines.extend([
            f"## 📝 Summary",
            f"",
            f"{review_result.summary}",
            f"",
        ])

    # Add vulnerabilities
    if review_result.vulnerabilities:
        report_lines.extend([
            f"## 🚨 Security Vulnerabilities ({len(review_result.vulnerabilities)})",
            f"",
        ])

        for i, vuln in enumerate(review_result.vulnerabilities, 1):
            severity_emoji = get_severity_emoji(vuln.get('severity', 'MEDIUM'))
            report_lines.extend([
                f"### {severity_emoji} {i}. {vuln.get('type', 'Unknown').replace('_', ' ').title()}",
                f"",
                f"**File:** `{vuln.get('file', 'N/A')}`",
                f"**Severity:** {vuln.get('severity', 'MEDIUM')}",
                f"",
                f"**Description:** {vuln.get('description', 'No description provided')}",
                f"",
                f"**Recommendation:** {vuln.get('recommendation', 'No recommendation provided')}",
                f"",
            ])

    # Add issues
    if review_result.issues:
        report_lines.extend([
            f"## ⚠️ Code Quality Issues ({len(review_result.issues)})",
            f"",
        ])

        for i, issue in enumerate(review_result.issues, 1):
            severity_emoji = get_severity_emoji(issue.get('severity', 'MEDIUM'))
            report_lines.extend([
                f"### {severity_emoji} {i}. {issue.get('type', 'Unknown').replace('_', ' ').title()}",
                f"",
                f"**File:** `{issue.get('file', 'N/A')}`",
                f"**Severity:** {issue.get('severity', 'MEDIUM')}",
                f"",
                f"**Description:** {issue.get('description', 'No description provided')}",
                f"",
                f"**Recommendation:** {issue.get('recommendation', 'No recommendation provided')}",
                f"",
            ])

    # Add recommendations
    if review_result.recommendations:
        report_lines.extend([
            f"## 💡 Recommendations",
            f"",
        ])

        for i, rec in enumerate(review_result.recommendations, 1):
            report_lines.append(f"{i}. {rec}")

        report_lines.append("")

    # Add footer
    report_lines.extend([
        f"---",
        f"*Generated by AI Code Reviewer v1.0*"
    ])

    return "\n".join(report_lines)


def get_score_emoji(score):
    """Get emoji based on score"""
    if score >= 90:
        return "🟢 Excellent"
    elif score >= 70:
        return "🟡 Good"
    elif score >= 50:
        return "🟠 Fair"
    else:
        return "🔴 Poor"


def get_severity_emoji(severity):
    """Get emoji based on severity"""
    severity_map = {
        'CRITICAL': '🚨',
        'HIGH': '🔴',
        'MEDIUM': '🟡',
        'LOW': '🟢'
    }
    return severity_map.get(severity, '⚠️')


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'False').lower() == 'true'

    app.run(
        host='0.0.0.0',
        port=port,
        debug=debug
    )