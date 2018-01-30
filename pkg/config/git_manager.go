package config

import "github.com/flant/dapp/pkg/config/ruby_marshal_config"

type GitManager struct {
	Local  []*GitLocal
	Remote []*GitRemote
}

func (c *GitManager) ToRuby() ruby_marshal_config.GitArtifact {
	gitArtifact := &ruby_marshal_config.GitArtifact{}

	if len(c.Local) != 0 {
		rubyGitArtifactLocal := ruby_marshal_config.GitArtifactLocal{}
		for _, local := range c.Local {
			rubyGitArtifactLocal.Export = append(rubyGitArtifactLocal.Export, local.ToRuby())
		}
		gitArtifact.Local = []ruby_marshal_config.GitArtifactLocal{rubyGitArtifactLocal}
	}

	if len(c.Remote) != 0 {
		rubyGitArtifactRemote := ruby_marshal_config.GitArtifactRemote{}
		for _, remote := range c.Remote {
			rubyGitArtifactRemote.Export = append(rubyGitArtifactRemote.Export, remote.ToRuby())
		}
		gitArtifact.Remote = []ruby_marshal_config.GitArtifactRemote{rubyGitArtifactRemote}
	}

	return *gitArtifact
}