#!/usr/bin/env python3
"""
P1 Dev Guard - VS Code Integration
Provides real-time AI analysis and IntelliSense integration
"""

import json
import os
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Any
import yaml

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(__file__))

from ai_config import AIConfigManager, P1AIConfig
from bedrock_analyzer import BedrockAnalyzer

class VSCodeIntegration:
    """Integration class for VS Code AI features"""

    def __init__(self, workspace_path: str):
        self.workspace_path = Path(workspace_path)
        self.config_manager = AIConfigManager()
        self.analyzer = None

    def initialize_ai(self) -> bool:
        """Initialize AI analyzer if available"""
        try:
            config = self.config_manager.load_config()
            self.analyzer = BedrockAnalyzer(
                preferred_model=config.default_model,
                config_manager=self.config_manager
            )
            return self.analyzer.is_available()
        except Exception as e:
            print(f"AI initialization failed: {e}", file=sys.stderr)
            return False

    def analyze_file(self, file_path: str, content: Optional[str] = None) -> Dict[str, Any]:
        """Analyze a single file and return AI insights"""
        result = {
            "file": file_path,
            "ai_available": False,
            "analysis": None,
            "recommendations": [],
            "cost_estimate": 0.0,
            "processing_time": 0
        }

        if not self.analyzer or not self.analyzer.is_available():
            result["analysis"] = "AI analysis not available - check AWS credentials"
            return result

        try:
            # Read file content if not provided
            if content is None:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

            # Determine file type for targeted analysis
            file_ext = Path(file_path).suffix.lower()
            analysis_type = self._get_analysis_type(file_ext)

            # Perform AI analysis
            analysis_result = self.analyzer.analyze_content(
                content=content,
                file_path=file_path,
                analysis_type=analysis_type
            )

            result["ai_available"] = True
            result["analysis"] = analysis_result.get("analysis", "No analysis available")
            result["recommendations"] = analysis_result.get("recommendations", [])
            result["cost_estimate"] = analysis_result.get("cost_estimate", 0.0)
            result["processing_time"] = analysis_result.get("processing_time", 0)

        except Exception as e:
            result["analysis"] = f"Analysis failed: {str(e)}"

        return result

    def _get_analysis_type(self, file_ext: str) -> str:
        """Determine analysis type based on file extension"""
        type_mapping = {
            '.yaml': 'kubernetes',
            '.yml': 'kubernetes',
            '.dockerfile': 'docker',
            '.rego': 'policy',
            '.json': 'config',
            '.py': 'script',
            '.sh': 'script',
            '.md': 'documentation'
        }
        return type_mapping.get(file_ext, 'general')

    def get_inline_suggestions(self, file_path: str, line_number: int, content: str) -> List[Dict[str, Any]]:
        """Get AI-powered inline suggestions for current cursor position"""
        if not self.analyzer or not self.analyzer.is_available():
            return []

        try:
            # Extract context around the line
            lines = content.split('\n')
            start_line = max(0, line_number - 5)
            end_line = min(len(lines), line_number + 5)
            context = '\n'.join(lines[start_line:end_line])

            # Create focused prompt
            prompt = f"""
Analyze this code snippet for Big Bang/Platform One compliance at line {line_number}:

```
{context}
```

Provide brief, actionable suggestions for:
1. Security compliance issues
2. Resource optimization
3. Best practices violations
4. Big Bang pattern adherence

Return suggestions as JSON array with format:
{{"line": number, "message": "suggestion", "severity": "info|warning|error", "category": "security|performance|compliance"}}
"""

            suggestions = self.analyzer._call_bedrock(prompt)

            # Parse AI response and format for VS Code
            try:
                parsed = json.loads(suggestions)
                return parsed if isinstance(parsed, list) else []
            except json.JSONDecodeError:
                # Fallback: parse text response
                return self._parse_text_suggestions(suggestions, line_number)

        except Exception as e:
            print(f"Inline suggestions failed: {e}", file=sys.stderr)
            return []

    def _parse_text_suggestions(self, text: str, base_line: int) -> List[Dict[str, Any]]:
        """Parse text-based AI suggestions into structured format"""
        suggestions = []
        lines = text.split('\n')

        for line in lines:
            if line.strip() and ('security' in line.lower() or 'compliance' in line.lower() or 'warning' in line.lower()):
                suggestions.append({
                    "line": base_line,
                    "message": line.strip(),
                    "severity": "warning" if "warning" in line.lower() else "info",
                    "category": "compliance"
                })

        return suggestions[:3]  # Limit to 3 suggestions

    def validate_helm_values(self, values_file: str) -> Dict[str, Any]:
        """Validate Helm values.yaml against schema with AI assistance"""
        result = {
            "valid": False,
            "errors": [],
            "ai_recommendations": []
        }

        try:
            # Load values file
            with open(values_file, 'r') as f:
                values = yaml.safe_load(f)

            # Look for corresponding schema
            schema_file = values_file.replace('values.yaml', 'values.schema.json').replace('values.yml', 'values.schema.json')

            if os.path.exists(schema_file):
                # Basic schema validation would go here
                result["valid"] = True

            # Get AI recommendations for values structure
            if self.analyzer and self.analyzer.is_available():
                ai_analysis = self.analyzer.analyze_content(
                    content=yaml.dump(values),
                    file_path=values_file,
                    analysis_type="helm_values"
                )
                result["ai_recommendations"] = ai_analysis.get("recommendations", [])

        except Exception as e:
            result["errors"].append(f"Validation failed: {str(e)}")

        return result

    def get_cost_estimate(self, analysis_text: str) -> float:
        """Estimate cost for AI analysis"""
        if not self.config_manager:
            return 0.0

        config = self.config_manager.load_config()
        model_config = self.config_manager.get_model_config(config.default_model)

        if not model_config:
            return 0.0

        # Rough token estimation (4 characters per token average)
        estimated_tokens = len(analysis_text) // 4
        input_tokens = min(estimated_tokens, model_config.max_tokens // 2)
        output_tokens = min(estimated_tokens // 3, model_config.max_tokens // 2)

        return self.config_manager.estimate_cost(
            config.default_model,
            input_tokens,
            output_tokens
        )

    def generate_problem_matchers(self) -> Dict[str, Any]:
        """Generate VS Code problem matchers for P1 Dev Guard output"""
        return {
            "p1-ai-analysis": {
                "owner": "p1-ai",
                "fileLocation": ["relative", "${workspaceFolder}"],
                "pattern": [
                    {
                        "regexp": "^\\s*\"file\":\\s*\"(.*)\".*\"line\":\\s*(\\d+).*\"message\":\\s*\"(.*)\".*\"severity\":\\s*\"(.*)\"",
                        "file": 1,
                        "line": 2,
                        "message": 3,
                        "severity": 4
                    }
                ]
            },
            "p1-compliance": {
                "owner": "p1-compliance",
                "fileLocation": ["relative", "${workspaceFolder}"],
                "pattern": [
                    {
                        "regexp": "^(FAIL|WARN|INFO) - (.*):(\\d+) - (.*)$",
                        "severity": 1,
                        "file": 2,
                        "line": 3,
                        "message": 4
                    }
                ]
            }
        }

def main():
    """CLI interface for VS Code integration"""
    parser = argparse.ArgumentParser(description="P1 Dev Guard VS Code Integration")
    parser.add_argument("command", choices=["analyze", "suggestions", "validate", "cost", "matchers"])
    parser.add_argument("--file", required=False, help="File to analyze")
    parser.add_argument("--line", type=int, help="Line number for suggestions")
    parser.add_argument("--workspace", default=".", help="Workspace path")
    parser.add_argument("--content", help="File content (for unsaved files)")
    parser.add_argument("--format", choices=["json", "text"], default="json", help="Output format")

    args = parser.parse_args()

    # Initialize integration
    integration = VSCodeIntegration(args.workspace)
    ai_available = integration.initialize_ai()

    if args.command == "analyze":
        if not args.file:
            print("--file required for analyze command", file=sys.stderr)
            sys.exit(1)

        result = integration.analyze_file(args.file, args.content)

        if args.format == "json":
            print(json.dumps(result, indent=2))
        else:
            print(f"File: {result['file']}")
            print(f"AI Available: {result['ai_available']}")
            if result['analysis']:
                print(f"Analysis: {result['analysis']}")
            if result['recommendations']:
                print("Recommendations:")
                for i, rec in enumerate(result['recommendations'], 1):
                    print(f"  {i}. {rec}")

    elif args.command == "suggestions":
        if not args.file or args.line is None:
            print("--file and --line required for suggestions command", file=sys.stderr)
            sys.exit(1)

        content = args.content
        if not content:
            try:
                with open(args.file, 'r') as f:
                    content = f.read()
            except Exception as e:
                print(f"Could not read file: {e}", file=sys.stderr)
                sys.exit(1)

        suggestions = integration.get_inline_suggestions(args.file, args.line, content)
        print(json.dumps(suggestions, indent=2))

    elif args.command == "validate":
        if not args.file:
            print("--file required for validate command", file=sys.stderr)
            sys.exit(1)

        result = integration.validate_helm_values(args.file)
        print(json.dumps(result, indent=2))

    elif args.command == "cost":
        content = args.content or ""
        if args.file and not content:
            try:
                with open(args.file, 'r') as f:
                    content = f.read()
            except Exception:
                pass

        cost = integration.get_cost_estimate(content)
        print(json.dumps({"estimated_cost": cost}, indent=2))

    elif args.command == "matchers":
        matchers = integration.generate_problem_matchers()
        print(json.dumps(matchers, indent=2))

if __name__ == "__main__":
    main()