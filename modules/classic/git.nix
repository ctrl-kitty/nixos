{ ... }:
{
  programs.git = {
	enable = true;
	config = {
	  user = {
		name = "ctrl-kitty";
		email = "<>";
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
