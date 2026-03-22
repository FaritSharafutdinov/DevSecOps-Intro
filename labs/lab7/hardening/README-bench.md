# Re-running CIS Docker Bench (Lab 7)

The official `docker/docker-bench-security` image ships Docker CLI 18.x and cannot talk to Docker Engine 29.x.

**Approach used here**

1. Build helper image (deps only, no host `/etc` mount during build):

   ```bash
   docker build -t lab7-bench-runner -f labs/lab7/hardening/Dockerfile.bench-runner labs/lab7/hardening
   ```

2. Clone upstream scripts (once), normalize line endings to LF on Windows:

   ```powershell
   git clone --depth 1 https://github.com/docker/docker-bench-security.git labs/lab7/hardening/docker-bench-security-src
   # then convert *.sh to LF (see lab automation or dos2unix)
   ```

3. Run (paths as on your machine):

   ```powershell
   $src = "c:/path/to/DevSecOps-Intro/labs/lab7/hardening/docker-bench-security-src"
   docker run --rm --net host --pid host --cap-add audit_control `
     -v "//var/run/docker.sock:/var/run/docker.sock" `
     -v "//var/lib/docker:/var/lib/docker:ro" `
     -v "//etc:/etc:ro" `
     -v "//usr/lib/systemd:/usr/lib/systemd:ro" `
     -v "${src}:/opt/bench" `
     -w /opt/bench lab7-bench-runner bash docker-bench-security.sh
   ```

**Why not mount host `/etc` into Alpine then `apk add`?** It replaces Alpine `/etc` and breaks `apk`.
