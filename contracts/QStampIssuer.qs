// Copyright 2026 Quantova Inc
// SPDX-License-Identifier: Apache-2.0 OR MIT

contract QStampIssuer {
  state {
    owner: Q_Address;
    issuer: Q_Address;
    pending_owner: Q_Address;
    pending_issuer: Q_Address;
    domain: u64;
    stamped: Registry<Q_Address>;
    stamped_hi: Map<Q_Address, u128>;
    stamped_lo: Map<Q_Address, u128>;
    revoked: Map<Q_Address, u64>;
  }
  // Sets the deploying account as the owner and the issuer given at deployment as the first authorised issuer.
  genesis {
    owner = deployer;
    issuer = deploy_params.issuer;
    domain = deploy_params.domain;
    guard issuer != native;
    guard domain != 0;
  }
  // Records a commitment only when the order carries a valid signature from the authorised issuer.
  entry stamp(order: StampOrder signed by issuer)
    reads(issuer, domain)
    writes(stamped, stamped_hi, stamped_lo)
    denies stamped.contains(order.commitment)
  {
    guard order.domain == domain;
    guard caller == issuer;
    guard now <= order.deadline;
    stamped.insert(order.commitment);
    stamped_hi.set(order.commitment, order.hi);
    stamped_lo.set(order.commitment, order.lo);
    emit Stamped(issuer, order.hi, order.lo, order.kind);
  }
  // Records that the issuer has withdrawn an earlier commitment, with a reason code chosen by the institution.
  entry revoke(order: RevokeOrder signed by issuer)
    reads(issuer, domain, stamped, stamped_hi, stamped_lo)
    writes(revoked)
    denies !stamped.contains(order.commitment)
    denies revoked.contains(order.commitment)
  {
    guard order.domain == domain;
    guard caller == issuer;
    guard now <= order.deadline;
    guard order.reason != 0;
    revoked.set(order.commitment, order.reason);
    emit Revoked(issuer, stamped_hi.get(order.commitment), stamped_lo.get(order.commitment), order.reason);
  }
  // Lets the owner appoint a new authorised issuer, for example after a key rotation.
  entry set_issuer(order: IssuerOrder signed by owner)
    reads(issuer, domain)
    writes(pending_issuer)
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    guard order.issuer != native;
    pending_issuer = order.issuer;
    emit IssuerProposed(issuer, order.issuer);
  }
  entry accept_issuer(order: AcceptOrder signed by pending_issuer)
    reads(domain)
    writes(issuer, pending_issuer)
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    emit IssuerChanged(issuer, pending_issuer);
    issuer = pending_issuer;
    pending_issuer = native;
  }
  entry propose_owner(order: OwnerOrder signed by owner)
    reads(domain)
    writes(pending_owner)
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    guard order.owner != native;
    pending_owner = order.owner;
    emit OwnerProposed(owner, order.owner);
  }
  entry accept_owner(order: AcceptOrder signed by pending_owner)
    reads(domain)
    writes(owner, pending_owner)
  {
    guard order.domain == domain;
    guard now <= order.deadline;
    emit OwnerChanged(owner, pending_owner);
    owner = pending_owner;
    pending_owner = native;
  }
  event Stamped(issuer: Q_Address, hi: u128, lo: u128, kind: u64);
  event Revoked(issuer: Q_Address, hi: u128, lo: u128, reason: u64);
  event IssuerProposed(issuer: Q_Address, proposed: Q_Address);
  event IssuerChanged(previous: Q_Address, issuer: Q_Address);
  event OwnerProposed(owner: Q_Address, proposed: Q_Address);
  event OwnerChanged(previous: Q_Address, owner: Q_Address);
}
