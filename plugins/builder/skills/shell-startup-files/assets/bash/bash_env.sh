# BASH_ENV file -- read by NON-interactive Bash (scripts, bash -c) when the
# BASH_ENV variable names this file. Not read when Bash runs as sh.
#
# Enable for cron:      BASH_ENV=/home/me/.config/bash/env.sh  (crontab line)
#                       SHELL=/bin/bash
# Enable for a session: export BASH_ENV="${HOME}/.config/bash/env.sh"
#
# Every Bash script started from that environment pays for this file, so keep
# it to exports. No output, no aliases, nothing slow.

case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) ;;
  *) PATH="${HOME}/.local/bin:${PATH}" ;;
esac
export PATH
