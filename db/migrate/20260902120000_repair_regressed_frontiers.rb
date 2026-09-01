# See Curriculum::RepairRegressedFrontiers: repoints course frontiers that were
# dragged backwards by starting `adventures-in-poetry` on the reopened
# `advanced-loops` level (forum t/2248).
class RepairRegressedFrontiers < ActiveRecord::Migration[8.1]
  def up
    Curriculum::RepairRegressedFrontiers.()
  end

  def down
    # The regressed pointers carry no information worth restoring.
  end
end
