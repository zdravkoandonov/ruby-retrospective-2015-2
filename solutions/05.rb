require 'digest/sha1'

class ObjectStore
  TIME_FORMAT = "%a %b %d %H:%M %Y %z".freeze

  attr_accessor :current_branch, :stage, :store

  def initialize()
    @current_branch = :master
    @stage = {}
    @objects_changed = 0
    @store = {master: []}
  end

  def self.init()
    new_store = new
    new_store.instance_eval(&Proc.new) if block_given?
    new_store
  end

  class Outcome
    attr_reader :message, :result

    def initialize(message, success, result = nil)
      @message = message
      @success = success
      @result = result
    end

    def success?
      @success
    end

    def error?
      not @success
    end
  end

  class Commit
    attr_reader :date, :message, :hash, :stage

    def initialize(date, message, hash, stage)
      @date = date
      @message = message
      @hash = hash
      @stage = stage
    end

    def objects
      @stage.values
    end
  end

  def add(name, object)
    @stage[name] = object
    @objects_changed += 1
    Outcome.new("Added #{name} to stage.", true, object)
  end

  def remove(name)
    if @stage.has_key?(name)
      removed_object = @stage[name]
      @stage.delete(name)
      @objects_changed += 1
      Outcome.new("Added #{name} for removal.", true, removed_object)
    else
      Outcome.new("Object #{name} is not committed.", false)
    end
  end

  def commit(message)
    if @objects_changed == 0
      Outcome.new("Nothing to commit, working directory clean.", false)
    else
      time = Time.now
      time_string = time.strftime(TIME_FORMAT)
      hash = Digest::SHA1.hexdigest(time_string + message)
      new_commit = Commit.new(time, message, hash, @stage.dup)
      @store[@current_branch] << new_commit
      outcome_message = "#{message}\n\t#{@objects_changed} objects changed"
      @objects_changed = 0
      Outcome.new(outcome_message, true, new_commit)
    end
  end

  def get(name)
    last_commit = @store[@current_branch].last
    if last_commit and last_commit.stage.has_key?(name)
      Outcome.new("Found object #{name}.",
                  true,
                  @store[@current_branch].last.stage[name])
    else
      Outcome.new("Object #{name} is not committed.", false)
    end
  end

  def checkout(commit_hash)
    commit_index = @store[@current_branch].
      find_index { |commit| commit.hash == commit_hash }
    if commit_index
      @store[@current_branch].slice!((commit_index + 1)..-1)
      @stage = @store[@current_branch].last.stage
      Outcome.new("HEAD is now at #{@store[@current_branch].last.hash}.",
                  true,
                  @store[@current_branch].last)
    else
      Outcome.new("Commit #{commit_hash} does not exist.", false)
    end
  end

  def head
    if @store[@current_branch].empty?
      Outcome.new("Branch #{@current_branch} does not have any commits yet.",
                  false)
    else
      Outcome.new(@store[@current_branch].last.message,
                  true,
                  @store[@current_branch].last)
    end
  end

  def log
    if @store[@current_branch].empty?
      Outcome.new("Branch #{@current_branch} does not have any commits yet.",
                  false)
    else
      separate_messages = @store[@current_branch].reverse_each.map do |commit|
        "Commit #{commit.hash}\n" +
          "Date: #{commit.date.strftime(TIME_FORMAT)}\n\n" +
            "\t#{commit.message}"
      end
      Outcome.new(separate_messages.join("\n\n"), true)
    end
  end

  class Branch
    def initialize(repository)
      @repository = repository
    end

    def create(branch_name)
      if @repository.store.has_key?(branch_name.to_sym)
        Outcome.new("Branch #{branch_name} already exists.", false)
      else
        @repository.store[branch_name.to_sym] =
          @repository.store[@repository.current_branch].dup
        Outcome.new("Created branch #{branch_name}.", true)
      end
    end

    def remove(branch_name)
      if @repository.store.has_key?(branch_name.to_sym)
        if @repository.current_branch == branch_name.to_sym
          Outcome.new("Cannot remove current branch.", false)
        else
          @repository.store.delete(branch_name.to_sym)
          Outcome.new("Removed branch #{branch_name}.", true)
        end
      else
        Outcome.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def checkout(branch_name)
      if @repository.store.has_key?(branch_name.to_sym)
        @repository.current_branch = branch_name.to_sym
        checkout_branch = @repository.store[@repository.current_branch]
        if checkout_branch.empty?
          @repository.stage = {}
        else
          @repository.stage = checkout_branch.last.stage
        end
        Outcome.new("Switched to branch #{branch_name}.", true)
      else
        Outcome.new("Branch #{branch_name} does not exist.", false)
      end
    end

    def list
      sorted_keys_with_prefix = @repository.store.keys.sort.map do |branch_name|
        ((branch_name == @repository.current_branch) ? "* " : "  ") +
          branch_name.to_s
      end
      Outcome.new(sorted_keys_with_prefix.join("\n"), true)
    end
  end

  def branch()
    Branch.new(self)
  end
end
