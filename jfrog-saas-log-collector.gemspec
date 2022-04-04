# frozen_string_literal: true

require_relative 'lib/jfrog/saas/log/collector/version'

Gem::Specification.new do |spec|
  spec.name = 'jfrog-saas-log-collector'
  spec.version = Jfrog::Saas::Log::Collector::VERSION
  spec.authors = ['Vasuki Narayana']
  spec.email = ['vasukin@jfrog.com']

  spec.summary = 'JFrog Saas Log Collector gem is intended for downloading and extracting of log files generated in Artifactory or Xray on the Jfrog Cloud.'
  spec.description = 'JFrog Saas Log Collector gem is intended for downloading and extracting of log files generated in Artifactory or Xray on the Jfrog Cloud.'
  spec.homepage = 'https://github.com/jfrog/jfrog-saas-log-collector/wiki'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = 'https://github.com/jfrog/jfrog-saas-log-collector/wiki'
  spec.metadata['source_code_uri'] = 'https://github.com/jfrog/jfrog-saas-log-collector'
  spec.metadata['changelog_uri'] = 'https://github.com/jfrog/jfrog-saas-log-collector/commits/main'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'rake', '~> 13.0'

  spec.add_dependency 'minitest', '~> 5.0'

  spec.add_dependency 'rubocop', '~> 1.21'

  spec.add_dependency 'faraday', '~> 2.2.0'

  spec.add_dependency 'faraday-follow_redirects', '~> 0.2.0'

  spec.add_dependency 'faraday-gzip', '~> 0.1.0'

  spec.add_dependency 'faraday-retry', '~> 1.0.3'

  spec.add_dependency 'zlib', '~> 2.1.1'

  spec.add_dependency 'parallel', '~> 1.21.0'

  spec.add_dependency 'logger', '~> 1.5.0'

  spec.add_dependency 'rufus-scheduler', '~> 3.8.1'

  spec.add_dependency 'json-schema', '~> 2.8.1'

  spec.add_dependency 'addressable', '~> 2.8.0'

end
