# SecureFinOps Platform

A small Spring Boot service wrapped in a deliberately over-engineered DevSecOps pipeline. The application itself is simple on purpose — the real work here is the security tooling, the CI/CD plumbing, and the infrastructure-as-code around it.

I built this to learn how a security-first delivery pipeline actually fits together end to end, not just in slides. Every scanner, gate, and deployment step runs for real against a working service.

## What it actually is

At the center is `transaction-service`, a Spring Boot 4 REST API backed by PostgreSQL that handles financial transactions. It's intentionally minimal — a controller, an entity, a repository. If you're here for the application logic, there isn't much to see.

The interesting part is everything wrapped around it: two parallel CI systems (Jenkins and GitHub Actions), six security scanners, a SonarQube quality gate, containerized staging deployment with health checks, and the whole local environment provisioned through Terraform.

## The security pipeline

The Jenkins pipeline runs the following, roughly in this order:

- **Build & unit tests** — Maven build, then tests against a real PostgreSQL instance (credentials injected from Jenkins' credential store, never from the repo).
- **Gitleaks** — secret scanning. Runs on the working tree in Jenkins, and on the full git history in GitHub Actions, since secrets that were committed and later deleted still live in history.
- **Checkov** — scans the Terraform and Dockerfiles for misconfigurations. This is the scanner that caught my Jenkins image running as root with no healthcheck.
- **SonarQube** — static analysis with a Quality Gate that fails the build if code quality or security drops below threshold.
- **Semgrep** — SAST against Java rulesets, OWASP Top Ten, and secrets patterns.
- **Trivy (filesystem)** — dependency/SCA scanning against `pom.xml`.
- **Trivy (image)** — scans the built Docker image for OS and library CVEs before anything gets deployed.
- **Deploy to staging** — builds the image, runs it against the shared PostgreSQL, waits for the actuator health endpoint to come up.

Every scan produces a JSON report that's archived as a build artifact and emailed out on completion.

GitHub Actions mirrors a subset of this (Semgrep, Trivy, Gitleaks on full history) so the same checks run on every push independently of the local Jenkins box.

## Stack

| Layer | Tools |
|-------|-------|
| Application | Java 21, Spring Boot 4.0.6, PostgreSQL |
| CI/CD | Jenkins, GitHub Actions |
| Security | Gitleaks, Semgrep, Trivy, Checkov, SonarQube |
| Infrastructure | Terraform, Docker |
| Build | Maven |

## Running it locally

You'll need Docker and Terraform. The whole local environment — PostgreSQL, Jenkins (with a custom image that bundles the Docker CLI), SonarQube, and a shared Docker network — is defined under `infra/`.

```bash
cd infra/environments/local
terraform init
terraform apply
```

There are also helper scripts under `scripts/` (both bash and PowerShell) that wrap the apply/destroy cycle and start the app locally:

```bash
./scripts/start.sh    # spin up infra + run the app
./scripts/stop.sh     # tear everything down
```

Once Jenkins is up (give it a minute on first boot — it builds a custom image), it's on `http://localhost:8081`. SonarQube is on `:9000`. The staging service, once deployed, answers on `:8082`.

The Jenkins job pulls the pipeline definition straight from `jenkins/Jenkinsfile` via SCM, so changes to the pipeline are version-controlled like everything else.

## A note on the Docker-in-Docker setup

Jenkins runs as a container with the host's Docker socket mounted, so it can spin up scanner containers on demand. This works, but it has a sharp edge: paths inside the Jenkins container don't mean anything to the host's Docker daemon. Mounting `${WORKSPACE}` directly into a scanner silently mounts an empty directory — the scanners run, report nothing, and the pipeline goes green while actually checking nothing.

I hit this and it took a while to diagnose, because most scanners fail quietly on empty input. The fix was `--volumes-from`, which makes the scanner containers share Jenkins' volumes at identical paths. There's a full write-up in `docs/` if you're curious — it's a good cautionary tale about trusting green pipelines.

## Status

Done:

- Full Jenkins pipeline with all six scanners reading real source
- GitHub Actions workflows for SAST, SCA, secret scanning
- Terraform-provisioned local environment (PostgreSQL, Jenkins, SonarQube, networking)
- SonarQube quality gate, email reporting with attached scan reports

Planned:

- AWS environment (RDS, EC2 staging, S3 + DynamoDB for remote state)
- Kubernetes deployment with admission policies and runtime security (Falco)
- DAST with OWASP ZAP against staging
- Vulnerability aggregation in DefectDojo
- Image signing with Cosign

## Why

I'm working toward DevSecOps / cloud security roles, and I wanted something concrete to point at — a pipeline I'd actually built and debugged, not a tutorial I'd followed. The roadmap above is also roughly my study plan for AWS SAA and the Kubernetes certifications.
