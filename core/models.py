# core/models.py
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
from datetime import datetime


@dataclass
class Vulnerability:
    """Represents a security vulnerability found in code"""
    type: str
    severity: str  # CRITICAL, HIGH, MEDIUM, LOW
    file: str
    line: Optional[str] = None
    description: str = ""
    recommendation: str = ""
    matches: List[str] = None

    def __post_init__(self):
        if self.matches is None:
            self.matches = []


@dataclass
class CodeIssue:
    """Represents a code quality issue"""
    type: str  # code_quality, performance, maintainability, testing
    severity: str  # HIGH, MEDIUM, LOW
    file: str
    line: Optional[str] = None
    description: str = ""
    recommendation: str = ""


@dataclass
class ComplexityAnalysis:
    """Represents complexity analysis of the code changes"""
    cognitive_complexity: str  # LOW, MEDIUM, HIGH
    maintainability_impact: str  # POSITIVE, NEUTRAL, NEGATIVE
    testing_adequacy: str  # SUFFICIENT, NEEDS_IMPROVEMENT, INSUFFICIENT


@dataclass
class ReviewResult:
    """Complete result of an AI code review"""
    security_score: int  # 0-100
    quality_score: int  # 0-100
    vulnerabilities: List[Dict[str, Any]]
    issues: List[Dict[str, Any]]
    summary: str
    recommendations: List[str]
    approval: str  # APPROVE, REQUEST_CHANGES, COMMENT
    ai_confidence: float  # 0.0-1.0
    complexity_analysis: Optional[Dict[str, str]] = None
    timestamp: Optional[datetime] = None

    def __post_init__(self):
        if self.timestamp is None:
            self.timestamp = datetime.utcnow()

        # Ensure scores are within valid range
        self.security_score = max(0, min(100, self.security_score))
        self.quality_score = max(0, min(100, self.quality_score))

        # Ensure confidence is within valid range
        self.ai_confidence = max(0.0, min(1.0, self.ai_confidence))

        # Validate approval status
        valid_approvals = ['APPROVE', 'REQUEST_CHANGES', 'COMMENT']
        if self.approval not in valid_approvals:
            self.approval = 'COMMENT'

    @property
    def overall_score(self) -> int:
        """Calculate overall score as average of security and quality"""
        return int((self.security_score + self.quality_score) / 2)

    @property
    def critical_issues_count(self) -> int:
        """Count of critical/high severity issues"""
        count = 0

        # Count critical vulnerabilities
        for vuln in self.vulnerabilities:
            if vuln.get('severity') in ['CRITICAL', 'HIGH']:
                count += 1

        # Count high severity issues
        for issue in self.issues:
            if issue.get('severity') == 'HIGH':
                count += 1

        return count

    @property
    def needs_attention(self) -> bool:
        """Whether this PR needs immediate attention"""
        return (
                self.security_score < 70 or
                self.quality_score < 70 or
                self.critical_issues_count > 0 or
                self.approval == 'REQUEST_CHANGES'
        )

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization"""
        return {
            'security_score': self.security_score,
            'quality_score': self.quality_score,
            'overall_score': self.overall_score,
            'vulnerabilities': self.vulnerabilities,
            'issues': self.issues,
            'summary': self.summary,
            'recommendations': self.recommendations,
            'approval': self.approval,
            'ai_confidence': self.ai_confidence,
            'complexity_analysis': self.complexity_analysis,
            'critical_issues_count': self.critical_issues_count,
            'needs_attention': self.needs_attention,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None
        }


# core/__init__.py
"""Core models and utilities for AI Code Reviewer"""

from .models import ReviewResult, Vulnerability, CodeIssue, ComplexityAnalysis

__all__ = ['ReviewResult', 'Vulnerability', 'CodeIssue', 'ComplexityAnalysis']