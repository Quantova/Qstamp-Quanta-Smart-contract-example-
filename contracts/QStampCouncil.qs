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
    reads(epoch, domain)
    writes(proposed, rotation_armed)
    denies rotation_armed != 0
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    proposed = new_officials;
    rotation_armed = now;
    emit RotationArmed(approvals.digest, epoch);
  }
  // Replaces the officials with the proposed set once all five proposed officials confirm it.
  entry rotate(new_officials: GuardianSet<5>, order: RotateOrder, confirmations: Quorum<5 of 5, proposed>)
    reads(domain)
    writes(officials, rotation_armed, epoch)
    denies rotation_armed == 0
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    officials = new_officials;
    rotation_armed = 0;
    epoch = epoch + 1;
    emit Rotated(epoch);
  }
  entry cancel_rotation(order: CancelOrder, approvals: Quorum<2 of 5, officials>)
    reads(epoch, domain)
    writes(rotation_armed)
    denies rotation_armed == 0
  {
    guard order.domain == domain;
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
