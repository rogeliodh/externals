$:.unshift File.join(File.dirname(__FILE__), '..', 'lib') if $0 == __FILE__
require 'externals/test_case'
require 'externals/ext'
require 'externals/test/simple_git_with_sub'

module Externals
  module Test
    class TestOutOfDateGitSubproject < TestCase
      include ExtTestCase

      def test_checkout
        repository = SimpleGitWithSub.new
        repository.prepare

        assert File.exists?(File.join(repository.clean_dir, ".git"))

        workdir = File.join(root_dir, 'test', "tmp", "workdir")
        mkdir_p workdir

        Dir.chdir workdir do
          if File.exists?(repository.name)
            rm_r repository.name
          end

          Ext.run "checkout", "--git", repository.clean_dir

          assert !File.exists?(File.join(repository.name, "readme.txt"))
          assert File.exists?(File.join(repository.name, "simple_readme.txt"))
          assert !File.exists?(File.join(
              repository.name, "subs", repository.dependents[:basic].name, "simple_readme.txt")
          )
          assert File.exists?(File.join(
              repository.name, "subs", repository.dependents[:basic].name, "readme.txt")
          )

          readme = File.read(File.join(
              repository.name, "subs", repository.dependents[:basic].name, "readme.txt"))

          assert readme =~ /Line 4/i
          assert readme !~ /Line 5/i

          # let's update the subproject and make sure that ext update works.

          tmp = "tmp_update_sub"
          mkdir tmp
          Dir.chdir tmp do
            `git clone #{repository.dependents[:basic].clean_dir}`
            raise unless $? == 0

            repository.dependents[:basic].mark_dirty

            Dir.chdir repository.dependents[:basic].name do
              open 'readme.txt', 'a' do |f|
                f.write "line 5"
              end

              `git add .`
              raise unless $? == 0
              `git commit -m "added line 5 to readme.txt"`
              raise unless $? == 0
              `git push`
              raise unless $? == 0
            end
          end

          rm_rf tmp

          Dir.chdir repository.name do
            Ext.run "update"

            readme = File.read(File.join(
                "subs", repository.dependents[:basic].name, "readme.txt"))

            assert readme =~ /Line 4/i
            assert readme =~ /Line 5/i
            assert readme !~ /Line 6/i
          end
        end
      end
    end
  end
end