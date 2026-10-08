import { Quorum } from "quantova/primitives";
contract QStampCouncil {
  state {
    officials: GuardianSet<5>;
    rotation_armed: u64;
  }
  // Fixes the five official signing keys given at deployment.
  genesis {
    officials = deploy_params.officials;
  }
  // Records a commitment only when at least three of the five officials have approved it.
  entry stamp(order: StampOrder, approvals: Quorum<3 of 5, officials>) {
    emit Stamped(order.hi, order.lo, order.kind, approvals.digest);
  }
  // Starts the waiting period that must pass before the set of officials can be replaced.
  entry arm_rotation(approvals: Quorum<4 of 5, officials>)
    writes(rotation_armed)
  {
    rotation_armed = now;
    emit RotationArmed(approvals.digest);
  }
  // Replaces the officials once four of five approve and 24 hours have passed since the rotation was armed.
  entry rotate(new_officials: GuardianSet<5>, approvals: Quorum<4 of 5, officials>)
    writes(officials, rotation_armed)
    after 24 hours from rotation_armed
    denies rotation_armed == 0
  {
    officials = new_officials;
    rotation_armed = 0;
    emit Rotated(approvals.digest);
  }
  event Stamped(hi: u128, lo: u128, kind: u64, approvals: Q_Hash);
  event RotationArmed(digest: Q_Hash);
  event Rotated(digest: Q_Hash);
}
