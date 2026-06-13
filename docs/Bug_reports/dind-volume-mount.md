# Incident Report: Security Scanners Were Scanning Empty Directories (DinD Path Mismatch)

**Project:** SecureFinOps Platform
**Component:** Jenkins CI/CD pipeline (run locally, Docker Desktop on Windows + WSL2)
**Severity:** High — silent bug that invalidated security results
**Status:** Resolved

---

## Summary

Four security scanners in the pipeline (Gitleaks, Semgrep, Trivy Filesystem, Checkov) reported a green pipeline but were actually scanning empty directories. The pipeline *looked* healthy: reports generated, zero findings, all stages green. In reality, none of them could see the source code due to a path mismatch specific to the Docker-in-Docker (DinD) architecture.

The bug was exposed by Checkov — the only scanner that failed loudly instead of failing silently.

---

## Architectural Context

The Jenkins container has the host's Docker socket mounted:

```
/var/run/docker.sock -> /var/run/docker.sock
```

This lets Jenkins start other containers (Semgrep, Trivy, Checkov, etc.) — the Docker-in-Docker pattern via socket sharing. Each scanner ran as:

```
docker run --rm -v ${WORKSPACE}:/src <scanner-image> ...
```

where `${WORKSPACE}` = `/var/jenkins_home/workspace/SecureFineTech`.

---

## How the Bug Was Identified

### 1. Initial symptom

The Checkov stage failed consistently with:

```
Directory /tf/infra does not exist; skipping it
```

even though the `infra/` directory clearly existed in the repository and on GitHub.

### 2. First wrong hypothesis: the `/tf` mount path

The initial suspicion was that `/tf` (the in-container mount point) was the problem. This turned out to be incorrect: `/tf` is just an arbitrary internal mount point name, created automatically by Docker at runtime — identical to the `/src` used by Semgrep, which "appeared" to work.

### 3. Checking the workspace after the build

The first check was misleading:

```bash
docker exec securefinops-jenkins-local ls -la /var/jenkins_home/workspace/SecureFineTech/
# Result: only .git, nothing else
```

This caused temporary confusion — the workspace seemed empty. The real cause: `cleanWs()` ran in `post { always {} }` and wiped the workspace at the end of every build. The `docker exec` check was performed *after* the pipeline finished, so it saw an already-cleaned workspace.

### 4. Debugging during execution (the key moment)

The decisive step was moving the check *inside* the stage, to capture the real state during execution:

```groovy
stage('IaC Scan - Checkov') {
    steps {
        sh 'ls -la ${WORKSPACE}/'
        sh 'ls -la ${WORKSPACE}/infra/'
        sh '''docker run --rm -v ${WORKSPACE}:/tf bridgecrew/checkov ...'''
    }
}
```

The result was contradictory and revealing:

```
ls ${WORKSPACE}/infra/    ->  EXISTS (environments, modules, providers.tf)
docker run -v ${WORKSPACE}:/tf  ->  /tf/infra does not exist
```

Jenkins *saw* the files in its own filesystem, but the Checkov container mounted from `${WORKSPACE}` received an empty directory.

### 5. Confirming the root cause

Inspecting the Jenkins volume revealed the path mismatch:

```bash
docker volume inspect securefinops-jenkins-home-local
# "Mountpoint": "/var/lib/docker/volumes/securefinops-jenkins-home-local/_data"
```

---

## Root Cause

A path mismatch specific to Docker-in-Docker via socket sharing.

When Jenkins (itself a container) executes `docker run -v ${WORKSPACE}:/tf`:

- `${WORKSPACE}` = `/var/jenkins_home/workspace/SecureFineTech` — a path valid **only inside** the Jenkins container.
- The `docker run` command, however, is processed by the **host's Docker daemon** (via the mounted socket), not by the Jenkins container.
- The host daemon looks for `/var/jenkins_home/...` **on the host**, where that path does not exist (the real data lives under `/var/lib/docker/volumes/.../_data`).
- Not finding the path, Docker creates and mounts an **empty directory** instead of failing.

The result: scanners received an empty mount and reported zero findings — a perfect false negative.

### Why Only Checkov Exposed the Problem

| Scanner | Behavior with an empty mount | Why |
|---------|------------------------------|-----|
| Checkov | Failed loudly (`directory does not exist`) | Explicitly checks that the target directory exists |
| Semgrep | Appeared OK (0 findings on "3 files") | Scanned an empty directory without flagging the anomaly |
| Trivy FS | Appeared OK (0 vulnerabilities) | Found no files to analyze, reported clean |
| Trivy Image | Worked correctly | Doesn't depend on the mount — reads the image directly via the socket |

Checkov was, paradoxically, the most valuable: it turned a silent failure into a visible one.

---

## The Fix

Replacing the `-v ${WORKSPACE}:/path` mount with `--volumes-from`:

```groovy
docker run --rm \
    --volumes-from securefinops-jenkins-local \
    bridgecrew/checkov:latest \
    --directory ${WORKSPACE}/infra \
    ...
```

`--volumes-from securefinops-jenkins-local` instructs the scanner container to mount **exactly the same volumes, at the same paths** as the Jenkins container. This way `/var/jenkins_home/workspace/...` exists identically inside the scanner, with no need to know or guess the real host path.

The fix was applied to all four scanners that read the workspace: Gitleaks, Semgrep, Trivy Filesystem, Checkov.

### Secondary Issue Discovered During Remediation

After the fix, Trivy Filesystem — now scanning real content — contacted Maven Central for every dependency and was rate-limited (`429 Too Many Requests`, 30-minute block). Resolved with `TRIVY_OFFLINE_SCAN=true`, which limits scanning to the local vulnerability database, with no per-dependency external requests.

---

## Validation

Confirmation that the fix worked came from the increase in scanned volume:

- Checkov: 39 checks passed, 2 failed, 5221-byte JSON report (before: 0 bytes)
- Trivy FS: detects `pom.xml` and dependencies (before: 0 files)
- Trivy Image: 219 KB report, real scan (already worked, didn't depend on the mount)

---

## Lessons Learned

1. **A green pipeline doesn't mean a correct pipeline.** The most dangerous security bugs are silent false negatives — tooling runs, reports "all clean," but analyzes nothing.

2. **Failing loudly is a virtue.** Checkov was the most useful scanner precisely because it complained clearly, instead of silently passing over empty input.

3. **DinD via socket sharing runs commands on the host daemon.** Any path in a `-v` flag must be valid from the host's perspective, not the container issuing the command. `--volumes-from` cleanly resolves this gap.

4. **Debugging must capture state at execution time.** Checking the workspace *after* the build (when `cleanWs()` had already cleaned it) led to wrong conclusions; moving the check inside the stage unblocked the diagnosis.

---

## Appendix: Before / After Comparison

**Before (empty mount, false negative):**
```groovy
docker run --rm -v ${WORKSPACE}:/src semgrep/semgrep scan /src
```

**After (shared volume, real scan):**
```groovy
docker run --rm --volumes-from securefinops-jenkins-local \
    semgrep/semgrep scan ${WORKSPACE}
```
