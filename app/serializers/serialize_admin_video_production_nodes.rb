class SerializeAdminVideoProductionNodes
  include Mandate

  initialize_with :nodes

  def call
    nodes.map { |node| SerializeAdminVideoProductionNode.(node) }
  end
end
