// Copyright 2026 Quantova Inc
// SPDX-License-Identifier: Apache-2.0 OR MIT

import { Quorum } from "quantova/primitives";
contract QStampCouncil {
  state {
    officials: GuardianSet<5>;
    proposed: GuardianSet<5>;
    rotation_armed: u64;
    epoch: u64;
    domain: u64;
    arm_count: u64;
    rotation_confirmed: u64;
  }
  // Fixes the five official signing keys given at deployment.
  genesis {
    officials = deploy_params.officials;
    domain = deploy_params.domain;
    guard domain != 0;
    epoch = 1;
  }
  // Records a commitment only when at least three of the five officials have approved it.
  entry stamp(order: StampOrder, approvals: Quorum<3 of 5, officials>)
    reads(epoch, domain)
  {
    guard order.domain == domain;
    guard caller == order.relayer;
    guard now <= order.deadline;
    emit Stamped(order.relayer, order.hi, order.lo, order.kind);
    emit Approved(order.hi, order.lo, approvals.digest, epoch);
  }
  // Records a proposed set of officials once four of the five current officials approve it.
  entry arm_rotation(new_officials: GuardianSet<5>, order: ArmOrder, approvals: Quorum<4 of 5, officials>)
    reads(epoch, domain, arm_count)
    writes(proposed, rotation_armed, arm_count, rotation_confirmed)
    denies rotation_armed != 0
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    proposed = new_officials;
    arm_count = arm_count + 1;
    rotation_armed = arm_count;
    rotation_confirmed = 0;
    emit RotationArmed(approvals.digest, epoch);
  }
  // Records that all five proposed officials confirm the proposal armed under the given number in the current epoch.
  entry confirm_rotation(order: ConfirmOrder, confirmations: Quorum<5 of 5, proposed>)
    reads(epoch, domain, rotation_armed, proposed)
    writes(rotation_confirmed)
    denies rotation_armed == 0
    denies rotation_confirmed != 0
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    guard order.epoch == epoch;
    guard order.armed == rotation_armed;
    rotation_confirmed = rotation_armed;
    emit RotationConfirmed(confirmations.digest, rotation_armed, epoch);
  }
  // Installs exactly the armed and confirmed set once four of the five current officials approve it.
  entry rotate(order: RotateOrder, approvals: Quorum<4 of 5, officials>)
    reads(domain, proposed, rotation_armed, rotation_confirmed)
    writes(officials, rotation_armed, rotation_confirmed, epoch)
    denies rotation_armed == 0
    denies rotation_confirmed != rotation_armed
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    guard order.epoch == epoch;
    guard order.armed == rotation_armed;
    officials = proposed;
    rotation_armed = 0;
    rotation_confirmed = 0;
    epoch = epoch + 1;
    emit Rotated(epoch);
  }
  // Withdraws a pending proposal and any confirmation of it once two of the five current officials approve.
  entry cancel_rotation(order: CancelOrder, approvals: Quorum<2 of 5, officials>)
    reads(epoch, domain)
    writes(rotation_armed, rotation_confirmed)
    denies rotation_armed == 0
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    rotation_armed = 0;
    rotation_confirmed = 0;
    emit RotationCancelled(approvals.digest, epoch);
  }
  event Stamped(sender: Q_Address, hi: u128, lo: u128, kind: u64);
  event Approved(hi: u128, lo: u128, approvals: Q_Hash, epoch: u64);
  event RotationArmed(digest: Q_Hash, epoch: u64);
  event RotationConfirmed(digest: Q_Hash, armed: u64, epoch: u64);
  event Rotated(epoch: u64);
  event RotationCancelled(digest: Q_Hash, epoch: u64);
}
