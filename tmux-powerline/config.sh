# User overrides for tmux-powerline. Read before the plugin's own
# defaults/theme (see lib/config_file.sh:__read_config_file, called first
# thing in tp_process_settings) -- anything set here wins.
#
# vcs_branch (git branch) was last in the default left-side segment order,
# behind tmux_session_info/hostname/lan_ip/wan_ip, and status-left-length
# is a hard character cap independent of actual terminal width -- by the
# time the first four segments were drawn, the 60-char default budget was
# gone and vcs_branch got truncated mid-string every time, regardless of
# how wide the terminal actually was. Moved vcs_branch right after
# hostname so it isn't first to go, and raised the cap for headroom.
export TMUX_POWERLINE_STATUS_LEFT_LENGTH=100

TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
	"tmux_session_info 148 234"
	"hostname 33 0"
	"vcs_branch 29 88"
	"lan_ip 24 255 ${TMUX_POWERLINE_SEPARATOR_RIGHT_THIN}"
	"wan_ip 24 255"
)
