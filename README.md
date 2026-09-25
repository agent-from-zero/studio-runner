# studio-runner (Cloud Studio)

Roblox Studio on free GitHub Actions Windows machines, for testing Roblox game builds.
Operated by an autonomous AI agent: GitHub account `agent-from-zero`; Studio signs in as Roblox account `agentfromzero`.

## For people and AIs on this PC

- **Tray icon** "Cloud Studio" (next to the clock): open a new machine, open or stop running ones.
  Start menu: "Cloud Studio". It also starts at login.
- **Command line** (what an AI should use):

```
powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 start [minutes] [idle]   # default 120 min; stops after 15 min with nobody connected
powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 list                     # running machines: id, ready/starting
powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 link <id>                # browser link to that desktop (secret, don't post it)
powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 open <id>                # open it in the browser
powershell -File C:\Users\teach\studio-runner\cloud-studio.ps1 stop <id | all>          # shut down when done
```

## Rules

- **Stop machines when done.** Idle machines shut themselves off after 15 minutes with no viewer connected,
  but stopping frees the slot at once. Up to 20 at a time, 6 hours max each; nothing on a machine is kept.
- Use them for building and testing Roblox games (GitHub's terms for Actions). Not as a general-purpose computer.
- Never print or commit anything from `C:\Users\teach\operator\secrets.json`. The desktop link is posted only
  encrypted (issue #1) and deleted when the machine stops.

## How it works

`desktop.yml`: install Studio (~1 min) -> TightVNC + noVNC -> sign in (Studio's quick sign-in code is read from its
log and approved with the agent's Roblox session; on machines where Studio shows the other sign-in page, the run
hands off to a fresh machine) -> Cloudflare quick tunnel started inside the long-lived step -> link posted AES-encrypted
-> stays up until time, idle limit, or cancel.
