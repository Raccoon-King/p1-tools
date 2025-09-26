#!/usr/bin/env python3
"""
P1 Dev Guard - Amazon Bedrock LLM Integration
AI-powered analysis and remediation suggestions for Big Bang compliance
"""

import json
import boto3
import logging
import os
import sys
from typing import Dict, List, Optional, Tuple
from botocore.exceptions import BotoCoreError, ClientError, NoCredentialsError
from ai_config import AIConfigManager, ModelConfig, P1AIConfig

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BedrockAnalyzer:
    """Amazon Bedrock LLM integration for P1 Dev Guard compliance analysis"""

    def __init__(self, region: str = "us-east-1", fallback_enabled: bool = True, config_path: Optional[str] = None):
        """Initialize Bedrock client with graceful fallback and configuration"""
        self.region = region
        self.client = None
        self.fallback_enabled = fallback_enabled

        # Load AI configuration
        self.config_manager = AIConfigManager(config_path)
        self.ai_config = self.config_manager.load_config()

        # Set preferred model from config
        self.preferred_model = self.ai_config.default_model

        # Override region if specified in model config
        model_config = self.config_manager.get_model_config(self.preferred_model)
        if model_config and model_config.region:
            self.region = model_config.region

    def initialize(self) -> bool:
        """Initialize Bedrock client and verify access"""
        try:
            # Create session to properly handle all credential sources
            session = boto3.Session()

            # Log credential source for debugging
            credentials = session.get_credentials()
            if credentials:
                cred_source = self._detect_credential_source(session)
                logger.info(f"🔐 Using AWS credentials from: {cred_source}")

            self.client = session.client('bedrock-runtime', region_name=self.region)

            # Test connection with a small request
            self._test_connection()
            logger.info(f"✅ Bedrock client initialized in {self.region}")
            return True

        except NoCredentialsError:
            logger.warning("⚠️  AWS credentials not found - AI analysis disabled")
            logger.info("💡 For IAM roles: ensure EC2 instance has Bedrock permissions")
            logger.info("💡 For IRSA: ensure ServiceAccount is properly configured")
            return False
        except Exception as e:
            logger.warning(f"⚠️  Bedrock initialization failed: {e} - AI analysis disabled")
            return False

    def _detect_credential_source(self, session: boto3.Session) -> str:
        """Detect and log the source of AWS credentials"""
        try:
            # Try to get current identity to determine credential source
            sts_client = session.client('sts', region_name=self.region)
            identity = sts_client.get_caller_identity()

            arn = identity.get('Arn', '')

            if 'assumed-role' in arn:
                if 'EKS' in arn or 'eks' in arn:
                    return "EKS Service Account (IRSA)"
                elif 'EC2' in arn or 'ec2' in arn:
                    return "EC2 Instance Role"
                elif 'ECS' in arn or 'ecs' in arn:
                    return "ECS Task Role"
                elif 'Lambda' in arn or 'lambda' in arn:
                    return "Lambda Execution Role"
                else:
                    return f"IAM Role: {arn.split('/')[-2]}"
            elif 'user' in arn:
                return "IAM User"
            else:
                return "AWS Credentials"

        except Exception as e:
            # Check environment variables as fallback
            if os.getenv('AWS_ROLE_ARN'):
                return "Environment Variable (AWS_ROLE_ARN)"
            elif os.getenv('AWS_PROFILE'):
                return f"AWS Profile: {os.getenv('AWS_PROFILE')}"
            elif os.getenv('AWS_ACCESS_KEY_ID'):
                return "Environment Variables"
            else:
                return "Unknown source"

    def _test_connection(self) -> None:
        """Test Bedrock connection with minimal request"""
        try:
            model_id = self.available_models[self.preferred_model]
            body = json.dumps({
                "messages": [{"role": "user", "content": "test"}],
                "max_tokens": 10,
                "anthropic_version": "bedrock-2023-05-31"
            })

            response = self.client.invoke_model(
                modelId=model_id,
                body=body,
                contentType="application/json"
            )
            logger.debug("Bedrock connection test successful")
        except Exception as e:
            raise Exception(f"Bedrock connection test failed: {e}")

    def analyze_compliance_findings(self, results_file: str) -> Dict:
        """Analyze compliance findings and provide insights (AI-powered if available, rule-based fallback)"""
        try:
            with open(results_file, 'r') as f:
                results = json.load(f)

            # Extract failed checks for analysis
            failed_checks = {k: v for k, v in results.get('checks', {}).items()
                           if v.get('status') == 'FAIL'}

            if not failed_checks:
                return {
                    "ai_analysis": {
                        "enabled": bool(self.client),
                        "mode": "bedrock" if self.client else "rule-based",
                        "summary": "🎉 No compliance issues found - all checks passed!",
                        "recommendations": ["Continue following Big Bang best practices", "Consider periodic policy reviews"],
                        "priority": "low"
                    }
                }

            # Try AI analysis first, fallback to rule-based
            if self.client:
                try:
                    analysis = self._generate_analysis(failed_checks, results)
                    return {"ai_analysis": analysis}
                except Exception as e:
                    logger.warning(f"AI analysis failed, using fallback: {e}")
                    if not self.fallback_enabled:
                        return {"ai_analysis": {"enabled": False, "error": str(e)}}

            # Fallback to rule-based analysis
            analysis = self._generate_fallback_analysis(failed_checks, results)
            return {"ai_analysis": analysis}

        except Exception as e:
            logger.error(f"Analysis failed: {e}")
            return {"ai_analysis": {"enabled": False, "error": str(e)}}

    def _generate_analysis(self, failed_checks: Dict, full_results: Dict) -> Dict:
        """Generate AI-powered analysis of compliance failures"""

        # Create context for the LLM
        context = self._build_context(failed_checks, full_results)

        # Generate analysis prompt
        prompt = self._build_analysis_prompt(context)

        # Call Bedrock
        response = self._call_bedrock(prompt)

        # Parse response
        return self._parse_analysis_response(response, failed_checks)

    def _build_context(self, failed_checks: Dict, full_results: Dict) -> Dict:
        """Build context information for LLM analysis"""
        return {
            "project_info": {
                "chart_path": full_results.get("chart_path"),
                "dockerfile_path": full_results.get("dockerfile_path"),
                "manifests_path": full_results.get("manifests_path")
            },
            "failed_checks": failed_checks,
            "summary": full_results.get("summary", {}),
            "configuration": full_results.get("configuration", {})
        }

    def _build_analysis_prompt(self, context: Dict) -> str:
        """Build the analysis prompt for the LLM"""
        return f"""You are a Platform One / Big Bang compliance expert. Analyze these compliance check failures and provide actionable remediation guidance.

CONTEXT:
- Project: {context['project_info']}
- Failed Checks: {len(context['failed_checks'])} out of {context.get('summary', {}).get('total', 'unknown')}
- Configuration: {context['configuration']}

FAILED CHECKS:
{json.dumps(context['failed_checks'], indent=2)}

Please provide:
1. PRIORITY ASSESSMENT: Categorize the overall risk level (critical/high/medium/low)
2. ROOT CAUSE ANALYSIS: Identify the main categories of issues
3. REMEDIATION STEPS: Specific, actionable steps to fix each issue
4. PREVENTION GUIDANCE: How to avoid these issues in the future
5. BIG BANG ALIGNMENT: How each fix aligns with Platform One standards

Format your response as JSON with this structure:
{{
  "priority": "critical|high|medium|low",
  "summary": "Brief overall assessment",
  "root_causes": ["cause1", "cause2", ...],
  "remediation_steps": [
    {{
      "check": "check_name",
      "issue": "description",
      "fix": "specific fix",
      "command": "example command if applicable",
      "docs_link": "relevant documentation URL"
    }}
  ],
  "prevention_tips": ["tip1", "tip2", ...],
  "estimated_effort": "time estimate to fix all issues"
}}

Focus on being practical and specific. Reference exact Big Bang requirements and provide working code examples where possible."""

    def _call_bedrock(self, prompt: str) -> str:
        """Call Amazon Bedrock with the analysis prompt using configured model"""
        try:
            model_config = self.config_manager.get_model_config(self.preferred_model)
            if not model_config:
                raise Exception(f"Model configuration not found for {self.preferred_model}")

            model_id = model_config.model_id

            # Build request body based on model provider and type
            if "anthropic" in model_id:
                body = json.dumps({
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": model_config.max_tokens,
                    "temperature": model_config.temperature,
                    "anthropic_version": "bedrock-2023-05-31"
                })
            elif "titan" in model_id:
                body = json.dumps({
                    "inputText": prompt,
                    "textGenerationConfig": {
                        "maxTokenCount": model_config.max_tokens,
                        "temperature": model_config.temperature,
                        "stopSequences": []
                    }
                })
            else:
                # Generic format for other models
                body = json.dumps({
                    "messages": [{"role": "user", "content": prompt}],
                    "max_tokens": model_config.max_tokens,
                    "temperature": model_config.temperature
                })

            # Make API call with configured endpoint if available
            invoke_kwargs = {
                "modelId": model_id,
                "body": body,
                "contentType": "application/json"
            }

            response = self.client.invoke_model(**invoke_kwargs)

            # Parse response based on model type
            response_body = json.loads(response['body'].read())

            if "anthropic" in model_id:
                return response_body['content'][0]['text']
            elif "titan" in model_id:
                return response_body['results'][0]['outputText']
            else:
                # Try to extract text from common response formats
                if 'content' in response_body and isinstance(response_body['content'], list):
                    return response_body['content'][0].get('text', '')
                elif 'text' in response_body:
                    return response_body['text']
                elif 'output' in response_body:
                    return response_body['output']
                else:
                    return str(response_body)

        except Exception as e:
            logger.error(f"Bedrock API call failed for model {self.preferred_model}: {e}")
            raise

    def _parse_analysis_response(self, response: str, failed_checks: Dict) -> Dict:
        """Parse and validate the LLM response"""
        try:
            # Try to extract JSON from the response
            response = response.strip()
            if response.startswith('```json'):
                response = response.split('```json')[1].split('```')[0]
            elif response.startswith('```'):
                response = response.split('```')[1].split('```')[0]

            analysis = json.loads(response)

            # Validate required fields and add defaults if missing
            return {
                "enabled": True,
                "model": self.preferred_model,
                "priority": analysis.get("priority", "medium"),
                "summary": analysis.get("summary", "AI analysis completed"),
                "root_causes": analysis.get("root_causes", []),
                "remediation_steps": analysis.get("remediation_steps", []),
                "prevention_tips": analysis.get("prevention_tips", []),
                "estimated_effort": analysis.get("estimated_effort", "unknown"),
                "issues_analyzed": len(failed_checks),
                "timestamp": full_results.get("timestamp", "")
            }

        except json.JSONDecodeError as e:
            logger.warning(f"Could not parse AI response as JSON: {e}")
            # Fallback to text analysis
            return {
                "enabled": True,
                "model": self.preferred_model,
                "priority": "medium",
                "summary": "AI analysis completed (text format)",
                "raw_response": response[:1000],  # Truncate for safety
                "issues_analyzed": len(failed_checks)
            }
        except Exception as e:
            logger.error(f"Error parsing AI response: {e}")
            return {
                "enabled": False,
                "error": str(e)
            }

    def _generate_fallback_analysis(self, failed_checks: Dict, full_results: Dict) -> Dict:
        """Generate rule-based analysis when Bedrock is unavailable"""

        # Categorize issues by type
        security_issues = []
        operational_issues = []
        policy_issues = []
        image_issues = []

        priority_score = 0
        remediation_steps = []

        for check_name, details in failed_checks.items():
            message = details.get('message', '')

            # Categorize by check type and create remediation steps
            if 'security' in check_name.lower() or 'privileged' in message.lower() or 'root' in message.lower():
                security_issues.append(check_name)
                priority_score += 3
                remediation_steps.append({
                    "check": check_name,
                    "issue": message,
                    "fix": self._get_security_fix(check_name, message),
                    "category": "security",
                    "docs_link": "https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/security-guide.md"
                })
            elif 'image' in check_name.lower() or 'latest' in message.lower() or 'ironbank' in message.lower():
                image_issues.append(check_name)
                priority_score += 2
                remediation_steps.append({
                    "check": check_name,
                    "issue": message,
                    "fix": self._get_image_fix(check_name, message),
                    "category": "image",
                    "docs_link": "https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/package-integration.md"
                })
            elif 'resource' in message.lower() or 'probe' in message.lower() or 'limit' in message.lower():
                operational_issues.append(check_name)
                priority_score += 1
                remediation_steps.append({
                    "check": check_name,
                    "issue": message,
                    "fix": self._get_operational_fix(check_name, message),
                    "category": "operational",
                    "docs_link": "https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/"
                })
            else:
                policy_issues.append(check_name)
                priority_score += 1
                remediation_steps.append({
                    "check": check_name,
                    "issue": message,
                    "fix": self._get_policy_fix(check_name, message),
                    "category": "policy",
                    "docs_link": "https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/developer/"
                })

        # Determine priority based on score
        if priority_score >= 6:
            priority = "critical"
        elif priority_score >= 4:
            priority = "high"
        elif priority_score >= 2:
            priority = "medium"
        else:
            priority = "low"

        # Generate summary
        total_issues = len(failed_checks)
        categories = []
        if security_issues:
            categories.append(f"{len(security_issues)} security")
        if image_issues:
            categories.append(f"{len(image_issues)} image")
        if operational_issues:
            categories.append(f"{len(operational_issues)} operational")
        if policy_issues:
            categories.append(f"{len(policy_issues)} policy")

        summary = f"Found {total_issues} compliance issues: {', '.join(categories)}"

        return {
            "enabled": True,
            "mode": "rule-based",
            "priority": priority,
            "summary": summary,
            "root_causes": self._identify_root_causes(failed_checks),
            "remediation_steps": remediation_steps,
            "prevention_tips": self._get_prevention_tips(security_issues, image_issues, operational_issues),
            "estimated_effort": self._estimate_effort(total_issues, priority_score),
            "issues_analyzed": total_issues,
            "categories": {
                "security": len(security_issues),
                "image": len(image_issues),
                "operational": len(operational_issues),
                "policy": len(policy_issues)
            }
        }

    def _get_security_fix(self, check_name: str, message: str) -> str:
        """Generate security-related fix suggestions"""
        if 'privileged' in message.lower():
            return "Set 'privileged: false' in securityContext and use specific capabilities instead"
        elif 'root' in message.lower():
            return "Set 'runAsUser' to a non-zero value (e.g., 65534) and 'runAsNonRoot: true'"
        elif 'allowPrivilegeEscalation' in message.lower():
            return "Set 'allowPrivilegeEscalation: false' in container securityContext"
        elif 'readOnlyRootFilesystem' in message.lower():
            return "Set 'readOnlyRootFilesystem: true' and mount writable volumes for temp directories"
        elif 'capabilities' in message.lower():
            return "Drop all capabilities with 'drop: [ALL]' and add only required ones"
        else:
            return "Review security context settings to follow Big Bang security standards"

    def _get_image_fix(self, check_name: str, message: str) -> str:
        """Generate image-related fix suggestions"""
        if 'latest' in message.lower():
            return "Replace ':latest' tag with specific version or digest (e.g., ':1.2.3' or '@sha256:...')"
        elif 'ironbank' in message.lower():
            return "Use Iron Bank registry: change image repository to start with registry.internal/ironbank/"
        elif 'digest' in message.lower():
            return "Pin image with digest for immutability: image@sha256:abcd1234..."
        elif 'pullPolicy' in message.lower():
            return "Set imagePullPolicy to 'IfNotPresent' for digest-based images or 'Always' for tags"
        else:
            return "Ensure container images follow Big Bang standards for registry and tagging"

    def _get_operational_fix(self, check_name: str, message: str) -> str:
        """Generate operational fix suggestions"""
        if 'resource' in message.lower() and 'request' in message.lower():
            return "Add resource requests: resources.requests.cpu and resources.requests.memory"
        elif 'resource' in message.lower() and 'limit' in message.lower():
            return "Add resource limits: resources.limits.cpu and resources.limits.memory"
        elif 'liveness' in message.lower():
            return "Add livenessProbe with httpGet, exec, or tcpSocket check"
        elif 'readiness' in message.lower():
            return "Add readinessProbe to ensure traffic only goes to ready pods"
        elif 'replicas' in message.lower():
            return "Increase replicas to 2 or more for high availability"
        else:
            return "Review operational readiness requirements for production deployment"

    def _get_policy_fix(self, check_name: str, message: str) -> str:
        """Generate policy-related fix suggestions"""
        if 'networkpolicy' in message.lower():
            return "Create NetworkPolicy with default-deny and explicit allow rules"
        elif 'serviceaccount' in message.lower():
            return "Create dedicated ServiceAccount (not 'default') for workload identity"
        elif 'tls' in message.lower() or 'ingress' in message.lower():
            return "Add TLS configuration to Ingress with cert-manager annotations"
        elif 'labels' in message.lower():
            return "Add required Big Bang labels: app.kubernetes.io/name, version, managed-by"
        else:
            return "Review Big Bang policy requirements and update manifest accordingly"

    def _identify_root_causes(self, failed_checks: Dict) -> List[str]:
        """Identify common root causes from failed checks"""
        causes = []
        messages = ' '.join([v.get('message', '') for v in failed_checks.values()]).lower()

        if 'ironbank' in messages or 'latest' in messages:
            causes.append("Non-compliant container images")
        if 'security' in messages or 'privileged' in messages or 'root' in messages:
            causes.append("Inadequate security configurations")
        if 'resource' in messages:
            causes.append("Missing resource specifications")
        if 'probe' in messages:
            causes.append("Missing health checks")
        if 'networkpolicy' in messages:
            causes.append("Insufficient network security")

        return causes or ["Configuration not aligned with Big Bang standards"]

    def _get_prevention_tips(self, security_issues: List, image_issues: List, operational_issues: List) -> List[str]:
        """Generate prevention tips based on issue types"""
        tips = []

        if security_issues:
            tips.extend([
                "Use Helm values.schema.json to enforce security settings",
                "Implement security policies in your CI/CD pipeline"
            ])
        if image_issues:
            tips.extend([
                "Set up automated image scanning in your registry",
                "Use dependabot or renovate for image updates"
            ])
        if operational_issues:
            tips.extend([
                "Create resource templates for consistent configurations",
                "Use monitoring to right-size resource requests"
            ])

        tips.extend([
            "Regular compliance scans with P1 Dev Guard",
            "Code reviews focusing on Big Bang standards"
        ])

        return tips

    def _estimate_effort(self, total_issues: int, priority_score: int) -> str:
        """Estimate effort to fix all issues"""
        if priority_score >= 6:
            return f"2-4 hours (critical issues require immediate attention)"
        elif priority_score >= 4:
            return f"1-2 hours (moderate complexity fixes)"
        elif total_issues > 5:
            return f"30-60 minutes (multiple simple fixes)"
        else:
            return f"15-30 minutes (straightforward fixes)"

    def generate_fix_suggestions(self, check_name: str, check_details: Dict, manifest_content: str = "") -> Dict:
        """Generate specific fix suggestions for a single compliance check"""
        if not self.client:
            return {"fix_available": False, "reason": "Bedrock not available"}

        try:
            prompt = f"""You are a Kubernetes and Big Bang security expert. Provide a specific fix for this compliance violation:

CHECK: {check_name}
STATUS: {check_details.get('status', 'FAIL')}
MESSAGE: {check_details.get('message', 'No message')}
DETAILS: {check_details.get('details', 'No details')}

MANIFEST CONTENT (if available):
{manifest_content[:2000] if manifest_content else 'Not provided'}

Provide a JSON response with:
{{
  "fix_type": "code_change|configuration|policy_exception",
  "difficulty": "easy|medium|hard",
  "description": "What this fix does",
  "yaml_fix": "Complete corrected YAML if applicable",
  "helm_values_fix": "Helm values.yaml changes if applicable",
  "explanation": "Why this fix is needed for Big Bang compliance"
}}

Focus on practical, working solutions that follow Big Bang best practices."""

            response = self._call_bedrock(prompt)
            fix_data = json.loads(response.strip())

            return {
                "fix_available": True,
                "check": check_name,
                **fix_data
            }

        except Exception as e:
            logger.error(f"Fix generation failed for {check_name}: {e}")
            return {"fix_available": False, "error": str(e)}

def main():
    """CLI entry point for Bedrock analyzer"""
    import argparse

    parser = argparse.ArgumentParser(description="P1 Dev Guard - AI Analysis")
    parser.add_argument("results_file", help="Path to P1 results JSON file")
    parser.add_argument("--region", default="us-east-1", help="AWS region")
    parser.add_argument("--model", choices=["claude-3-sonnet", "claude-3-haiku", "titan"],
                       default="claude-3-haiku", help="Bedrock model to use")
    parser.add_argument("--output", help="Output file for analysis results")

    args = parser.parse_args()

    # Initialize analyzer
    analyzer = BedrockAnalyzer(region=args.region)
    analyzer.preferred_model = args.model

    if not analyzer.initialize():
        print("❌ Could not initialize Bedrock - check AWS credentials and region")
        sys.exit(1)

    # Perform analysis
    analysis = analyzer.analyze_compliance_findings(args.results_file)

    # Output results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(analysis, f, indent=2)
        print(f"✅ AI analysis saved to {args.output}")
    else:
        print(json.dumps(analysis, indent=2))

if __name__ == "__main__":
    main()