#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
checks={
  'semantic bridge': ('scripts/render/room_stage.gd', 'WebE2EProbe.room_state'),
  'menu action rect': ('scripts/ui/experience_intro_card.gd', 'WebE2EProbe.control_action_deferred("menu", "continueRect"'),
  'completion action rect': ('scripts/ui/completion_card.gd', '_publish_e2e_actions'),
  'completion discriminator producer': ('scripts/app/web_e2e_probe.gd', 'detail["kind"] = kind'),
  'completion discriminator consumer': ('tests/e2e/full_game_web.py', "x.kind === 'completion'"),
  'finale readiness': ('scripts/app/main_reward_flow.gd', 'WebE2EProbe.emit("finale", {"ready":true'),
  'finale signal CTA': ('scripts/ui/signal_finale_card.gd', 'WebE2EProbe.emit("finale_actions"'),
  'signal conversion gate': ('tests/e2e/full_game_web.py', 'SYNESTHESIA_SIGNAL_CONVERSION_E2E=PASS'),
  'synthetic run': ('scripts/reward_client.gd', 'payload["synthetic"] = true'),
  'real pointer driver': ('tests/e2e/full_game_web.py', 'page.mouse.down()'),
  'save resume': ('tests/e2e/full_game_web.py', 'page.reload('),
  'runtime diagnostics': ('tests/e2e/full_game_web.py', 'bad_responses'),
  'audio state': ('scripts/audio_director.gd', 'func e2e_state() -> Dictionary:'),
  'audio e2e gate': ('tests/e2e/full_game_web.py', 'SYNESTHESIA_AUDIO_STATE_E2E=PASS'),
  'mobile viewport matrix': ('.github/workflows/ci.yml', '390x844 810x1440 1080x1920'),
  'preprod preview gate': ('.github/workflows/deploy-web.yml', 'Full-game preview E2E before production promotion'),
  'production promotion after preview': ('.github/workflows/deploy-web.yml', 'Promote exact prebuilt artifact to Netlify production'),
  'production post-deploy gate': ('.github/workflows/deploy-web.yml', 'SYNESTHESIA_PROD_E2E=PASS'),
}
missing=[]
driver=(ROOT/'tests/e2e/full_game_web.py').read_text(errors='replace')
if "x.phase === 'completion'" in driver:
    raise SystemExit('SYNESTHESIA_PRODUCTION_E2E_CONTRACT=FAIL stale-completion-discriminator=phase')
for name,(path,token) in checks.items():
    if token not in (ROOT/path).read_text(errors='replace'):
        missing.append(name)
if missing:
    raise SystemExit('SYNESTHESIA_PRODUCTION_E2E_CONTRACT=FAIL missing='+','.join(missing))
print('SYNESTHESIA_PRODUCTION_E2E_CONTRACT=PASS semantic-hints real-pointer synthetic-prod save-resume finale audio diagnostics viewports')
