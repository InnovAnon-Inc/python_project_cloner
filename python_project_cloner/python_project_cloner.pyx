# python_project_cloner
# handles -march= / -mtune= architecture-specific distribution

import os
import shutil
import subprocess
from pathlib import Path
from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
import httpx

app = FastAPI(title="Chimera Project Cloner")

# Configuration - should be moved to env vars
SHARED_VOLUME = Path("/mnt/shared_source")
DEBIANIZER_URL = os.getenv("DEBIANIZER_URL", "http://python_project_debianizer.innovanon.com:9322/debianize")

class CloneRequest(BaseModel):
    repo_url: str
    branch: str = "main"

async def orchestrate_build(repo_path: Path):
    """
    Coordinates the handoffs between the Swarm services.
    """
    async with httpx.AsyncClient(timeout=300.0) as client:
        try:
            # 1. Trigger the 'Surgeon' / 'Configurator' 
            # (Assuming you merge these into one 'Prep' service)
            print(f"🏥 Notifying Prep Service for {repo_path.name}...")
            # await client.post(...)

            # 2. Trigger the Debianizer
            print(f"📦 Notifying Debianizer for {repo_path.name}...")
            response = await client.post(DEBIANIZER_URL, json={"path": str(repo_path)})
            response.raise_for_status()
            
            # 3. Next step: The PPA Pusher
            # Once the .dsc is created in the parent dir, the Pusher takes over.
            print(f"🚀 Debianization complete for {repo_path.name}")
            
        except Exception as e:
            print(f"❌ Orchestration failed: {e}")

#@app.post("/clone")
#async def clone_repo(request: CloneRequest, background_tasks: BackgroundTasks):
#    # Determine directory name from URL
#    repo_name = request.repo_url.split("/")[-1].replace(".git", "")
#    target_path = SHARED_VOLUME / repo_name
#    
#    # Clean up if exists (or handle versioning)
#    if target_path.exists():
#        shutil.rmtree(target_path)
#    
#    # Clone logic
#    print(f"📥 Cloning {request.repo_url} into {target_path}")
#    result = subprocess.run(
#        ["git", "clone", "-b", request.branch, request.repo_url, str(target_path)],
#        capture_output=True, text=True
#    )
#    
#    if result.returncode != 0:
#        raise HTTPException(status_code=500, detail=f"Clone failed: {result.stderr}")
#
#    # Kick off the rest of the build process in the background
#    background_tasks.add_task(orchestrate_build, target_path)
#
#    return {"status": "cloning_started", "project": repo_name, "path": str(target_path)}

@app.post("/clone")
async def clone_repo(request: CloneRequest, background_tasks: BackgroundTasks):
    repo_name = request.repo_url.split("/")[-1].replace(".git", "")
    target_path = SHARED_VOLUME / repo_name

    # MOVE THE CLONING LOGIC INTO THE BACKGROUND TASK
    background_tasks.add_task(run_clone_and_orchestrate, request, target_path)

    return {"status": "accepted"} # Respond instantly to the Watchdog

async def run_clone_and_orchestrate(request, target_path):
    # 1. Heavy IO (Clone/Delete)
    if target_path.exists():
        shutil.rmtree(target_path)

    subprocess.run(["git", "clone", "-b", request.branch, request.repo_url, str(target_path)])

    # 2. Then Orchestrate
    await orchestrate_build(target_path)
