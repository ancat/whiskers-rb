# whiskers

## tl;dr:

* Watch for changes to `Gemfile.lock`
* Pull down old and new version of each gem
* Statically analyze changed files for malicious code
* ???
* No Profit (for the bad guys :)

## Summarize a Gemfile.lock change

```
$ bin/gemfile_diff Gemfile.lock.old Gemfile.lock

Added gems:
  + benchmark (0.4.0)
  + date (3.4.1)
  + logger (1.6.5)
  + securerandom (0.4.1)
  + uri (1.0.2)
  + useragent (0.16.11)

Changed versions:
  ~ concurrent-ruby: 1.3.4 → 1.3.5
  ~ connection_pool: 2.4.1 → 2.5.0
  ~ irb: 1.11.0 → 1.14.3
  ~ bogon-test: 1.24.0 → 1.26.3
  ~ parser: 3.3.0.5 → 3.3.7.0
  ~ pry: 0.14.2 → 0.15.2
  ~ rdoc: 6.6.3.1 → 6.11.0
  ~ regexp_parser: 2.9.0 → 2.10.0
  ~ reline: 0.4.1 → 0.6.0
```

## Dig Deeper into a Package Upgrade

```
$ bin/gem_diff bogon-test 1.24.0 1.26.3

Modified files:
  ~ lib/bogon-test/version.rb
  ~ lib/bogon-test.rb

Running Semgrep security scan on changed files...

New security findings in lib/bogon-test/version.rb:
  [semgrep-rules.ruby-system-command-execution] line 6: Dangerous shell command execution detected
        system("touch /tmp/xxx")
```
