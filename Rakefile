require 'yaml'

tasks = ['05', '06', '07', '08']

desc 'Checks everything'
task :check do
  tasks.each do |task_number|
    Rake::Task["tasks:#{task_number}"].invoke
  end
end

desc 'Starts a proecss to run tests on a task when its solution is modified'
task :watch do
  system 'bundle exec observr observr.rb'
end

namespace :tasks do
  tasks.each do |task_number|
    task(task_number) { Rake::Task['tasks:run'].execute(task_number) }
  end

  task :run, :task_id do |t, arg|
    index = arg
    Rake::Task['tasks:skeptic'].execute index
    Rake::Task['tasks:spec'].execute index
  end

  task :spec, :task_id do |t, arg|
    index = arg
    system("bundle exec rspec --require ./solutions/#{index}.rb --fail-fast --color specs/#{index}_spec.rb") or exit(1)
  end

  task :skeptic, :task_id do |t, arg|
    index = arg.to_i

    opts = YAML.load_file('skeptic.yml')[index].map do |setting, value|
      option_name = setting.to_s.tr('_', '-')
      option      = "--#{option_name}"

      case value
      when false then nil
      when true  then option
      else       "#{option}='#{value}'"
      end
    end

    system("bundle exec skeptic #{opts.join ' '} solutions/#{'%02d' % index}.rb") or exit(1)
  end
end
