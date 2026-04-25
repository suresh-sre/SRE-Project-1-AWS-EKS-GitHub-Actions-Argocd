import urllib.request, json
req = urllib.request.urlopen('https://api.github.com/repos/suresh-sre/SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd/actions/runs?per_page=1')
run_id = json.loads(req.read())['workflow_runs'][0]['id']
req = urllib.request.urlopen(f'https://api.github.com/repos/suresh-sre/SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd/actions/runs/{run_id}/jobs')
jobs = json.loads(req.read())['jobs']
for j in jobs:
    if j['conclusion'] == 'failure':
        print(f"Job: {j['name']} (ID: {j['id']})")
        
        # Get logs for this job
        log_url = f"https://api.github.com/repos/suresh-sre/SRE-Project-1-AWS-EKS-GitHub-Actions-Argocd/actions/jobs/{j['id']}/logs"
        try:
            req_log = urllib.request.urlopen(log_url)
            logs = req_log.read().decode('utf-8')
            lines = logs.split('\n')
            print('\n'.join(lines[-20:])) # print last 20 lines
        except Exception as e:
            print("Failed to get logs:", e)
        print("--------------------")
