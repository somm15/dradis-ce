class Issue < Note
  include Taggable

  # -- Relationships --------------------------------------------------------
  has_many :evidence, dependent: :destroy
  has_many :affected, through: :evidence, source: :node

  # `has_many :activities` doesn't work as normal here, because we're not
  # using proper single-table inheritance. (By default it will search
  # for activities where trackable_type is "Note" instead of "Issue".) So
  # we need to override Issue#activities with a hack.
  #
  # NOTE: doing it this way means we don't get some of the methods that
  # are automatically generated by has_many, such as `activity_ids`. Some
  # of the other methods listed at http://guides.rubyonrails.org/association_basics.html#has-many-association-reference
  # might not work as intended either. Proceed with caution.
  #
  # FIXME - ISSUE/NOTE INHERITANCE
  def activities(*params)
    Activity.where(trackable_type: "Issue", trackable_id: self.id)
  end


  # -- Callbacks ------------------------------------------------------------
  before_validation do
    self.category = Category.issue unless self.category
  end


  # -- Validations ----------------------------------------------------------


  # -- Scopes ---------------------------------------------------------------


  # -- Class Methods --------------------------------------------------------

  # Create a hash with all issues where the keys correspond to the field passed
  # as an argument
  def self.all_issues_by_field(field)
    # we don't memoize it because we want it to reflect recently added Issues
    issues_map = Issue.all.map do |issue|
      [issue.fields[field], issue]
    end
    Hash[issues_map]
  end


  # -- Instance Methods -----------------------------------------------------

  def <=>(other)
    self.title <=> other.title
  end

  # This method groups all the available evidence associated with this Issue
  # into a Hash where the keys are the nodes. E.g.:
  # {
  #   <node 1> => [<evidence 1.1>, <evidence 1.2>],
  #   <node 2> => [<evidence 2.1>]
  # }
  #
  # This is useful in a number of views to present or hide information about
  # all the instances for a given issue and node/host.
  def evidence_by_node()
    results = Hash.new{|h,k| h[k] = [] }

    self.evidence.includes(:node).each do |evidence|
      results[evidence.node] << evidence
    end

    # This sorts nodes by IP address. Non-IPs appear first
    results.sort_by do |node,_|
      node.label.split('.').map(&:to_i)
    end
  end

  # Move all Evidence attached to issues with ids in issue_ids
  # array to this issue.
  # Then delete those issues without Evidence.
  # Returns the number of issues affected.
  def combine(issue_ids)
    # assert current id is not there
    issue_ids = [issue_ids] if issue_ids.is_a?(Integer)
    issue_ids -= [id]

    combined = 0

    # combine
    if issue_ids.any?
      self.transaction do
        Evidence.where(issue_id: issue_ids).update_all(issue_id: id)
        combined = Issue.delete_all(id: issue_ids)
      end
    end

    combined
  end

end
