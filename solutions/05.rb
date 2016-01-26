require 'digest/sha1'

class ObjectStore
  module ObjectStore::CommandHelpers
    def error(message)
      ObjectStore::Outcome.new(message, false)
    end

    def success(message, result = nil)
      ObjectStore::Outcome.new(message, true, result)
    end
  end

  include CommandHelpers

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

  def add(name, object)
    @stage[name] = object
    @objects_changed += 1
    success("Added #{name} to stage.", object)
  end

  def remove(name)
    if @stage.has_key?(name)
      removed_object = @stage[name]
      @stage.delete(name)
      @objects_changed += 1
      success("Added #{name} for removal.", removed_object)
    else
      error("Object #{name} is not committed.")
    end
  end

  def commit(message)
    if @objects_changed == 0
      error("Nothing to commit, working directory clean.")
    else
      time = Time.now
      time_string = time.strftime(TIME_FORMAT)
      hash = Digest::SHA1.hexdigest(time_string + message)
      create_commit(message, time, hash)
    end
  end

  private def create_commit(message, time, hash)
    new_commit = Commit.new(time, message, hash, @stage.dup)
    @store[@current_branch] << new_commit
    outcome_message = "#{message}\n\t#{@objects_changed} objects changed"
    @objects_changed = 0
    success(outcome_message, new_commit)
  end

  def get(name)
    last_commit = @store[@current_branch].last
    if last_commit and last_commit.stage.has_key?(name)
      success("Found object #{name}.",
                  @store[@current_branch].last.stage[name])
    else
      error("Object #{name} is not committed.")
    end
  end

  def checkout(commit_hash)
    commit_index = @store[@current_branch].
      find_index { |commit| commit.hash == commit_hash }
    if commit_index
      @store[@current_branch].slice!((commit_index + 1)..-1)
      @stage = @store[@current_branch].last.stage
      success("HEAD is now at #{@store[@current_branch].last.hash}.",
                  @store[@current_branch].last)
    else
      error("Commit #{commit_hash} does not exist.")
    end
  end

  def head
    if @store[@current_branch].empty?
      error("Branch #{@current_branch} does not have any commits yet.")
    else
      success(@store[@current_branch].last.message,
                  @store[@current_branch].last)
    end
  end

  def log
    if @store[@current_branch].empty?
      error("Branch #{@current_branch} does not have any commits yet.")
    else
      separate_messages = @store[@current_branch].reverse_each.map do |commit|
        "Commit #{commit.hash}\n" +
          "Date: #{commit.date.strftime(TIME_FORMAT)}\n\n" +
            "\t#{commit.message}"
      end
      success(separate_messages.join("\n\n"))
    end
  end

  def branch()
    Branch.new(self)
  end
end

class ObjectStore::Outcome
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

class ObjectStore::Commit
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

class ObjectStore::Branch
  include ObjectStore::CommandHelpers

  def initialize(repository)
    @repository = repository
  end

  def create(branch_name)
    if @repository.store.has_key?(branch_name.to_sym)
      error("Branch #{branch_name} already exists.")
    else
      @repository.store[branch_name.to_sym] =
        @repository.store[@repository.current_branch].dup
      success("Created branch #{branch_name}.")
    end
  end

  def remove(branch_name)
    if @repository.store.has_key?(branch_name.to_sym)
      if @repository.current_branch == branch_name.to_sym
        error("Cannot remove current branch.")
      else
        @repository.store.delete(branch_name.to_sym)
        success("Removed branch #{branch_name}.")
      end
    else
      error("Branch #{branch_name} does not exist.")
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
      success("Switched to branch #{branch_name}.")
    else
      error("Branch #{branch_name} does not exist.")
    end
  end

  def list
    sorted_keys_with_prefix = @repository.store.keys.sort.map do |branch_name|
      ((branch_name == @repository.current_branch) ? "* " : "  ") +
        branch_name.to_s
    end
    success(sorted_keys_with_prefix.join("\n"))
  end
end
