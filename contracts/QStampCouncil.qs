import { Quorum } from "quantova/primitives";
contract QStampCouncil {
  state {
    officials: GuardianSet<5>;
    proposed: GuardianSet<5>;
    rotation_armed: u64;
    epoch: u64;
  }
  // Proposes the five official signing keys given at deployment, which take effect once all five confirm them.
  genesis {
    proposed = deploy_params.officials;
    rotation_armed = now;
  }
  // Records a commitment only when at least three of the five officials have approved it.
  entry stamp(order: StampOrder, approvals: Quorum<3 of 5, officials>)
    reads(epoch)
    denies epoch == 0
  {
    guard caller == order.relayer;
    guard now <= order.deadline;
    emit Stamped(order.relayer, order.hi, order.lo, order.kind);
    emit Approved(order.hi, order.lo, approvals.digest, epoch);
  }
  // Starts the waiting period that must pass before the set of officials can be replaced.
  entry arm_rotation(new_officials: GuardianSet<5>, order: ArmOrder, approvals: Quorum<4 of 5, officials>)
    reads(epoch)
    writes(proposed, rotation_armed)
    denies epoch == 0
  {
    guard now <= order.deadline;
    guard rotation_armed == 0 || now > rotation_armed + 691200;
    proposed = new_officials;
    rotation_armed = now;
    emit RotationArmed(approvals.digest, epoch);
  }
  // Replaces the officials with the armed set once all five proposed officials confirm it, between 24 hours and 8 days after the rotation was armed.
  entry rotate(new_officials: GuardianSet<5>, order: RotateOrder, confirmations: Quorum<5 of 5, proposed>)
    writes(officials, rotation_armed, epoch)
    after 24 hours from rotation_armed
    denies rotation_armed == 0
  {
    guard now <= order.deadline;
    guard now <= rotation_armed + 691200;
    officials = new_officials;
    rotation_armed = 0;
    epoch = epoch + 1;
    emit Rotated(epoch);
  }
  entry cancel_rotation(order: CancelOrder, approvals: Quorum<2 of 5, officials>)
    reads(epoch)
    writes(rotation_armed)
    denies epoch == 0
    denies rotation_armed == 0
  {
    guard now <= order.deadline;
    rotation_armed = 0;
    emit RotationCancelled(approvals.digest, epoch);
  }
  event Stamped(sender: Q_Address, hi: u128, lo: u128, kind: u64);
  event Approved(hi: u128, lo: u128, approvals: Q_Hash, epoch: u64);
  event RotationArmed(digest: Q_Hash, epoch: u64);
  event Rotated(epoch: u64);
  event RotationCancelled(digest: Q_Hash, epoch: u64);
}
