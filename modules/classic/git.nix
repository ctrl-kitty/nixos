{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
	delta
  ];
  programs.git = {
	enable = true;
	config = {
	  core.pager = "delta";
	  interactive.diffFilter = "delta --color-only";
	  delta = {
	    navigate = true;
	    line-numbers = true;
	    side-by-side = false;
	  };
	push.autoSetupRemote = true;
	  user = {
		name = "ctrl-kitty";
		email = "104305684+ctrl-kitty@users.noreply.github.com";
	  };
	  alias = {
		st = "status -sb";
		s = "status --short --branch";
		
		ll = "log --oneline";
		lg = "log --oneline --decorate --graph";
		last = "log -1 HEAD --stat";
		
		cm = "commit -m";
		ca = "commit --amend";
		cane = "commit --amend --no-edit";
		
		co = "checkout";
		br = "branch";
		
		d = "diff";
		ds = "diff --staged";
		
		p = "push";
		pf = "push --force-with-lease";
		pl = "pull";
		
		rv = "remote -v";
	  };
	};
  };
}
