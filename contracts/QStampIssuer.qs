contract QStampIssuer {
  state {
    owner: Q_Address;
    issuer: Q_Address;
  }
  // Sets the deploying account as both the owner and the first authorised issuer.
  genesis {
    owner = deployer;
    issuer = deployer;
  }
  // Records a commitment only when the order carries a valid signature from the authorised issuer.
  entry stamp(order: StampOrder signed by issuer)
    reads(issuer)
  {
    emit Stamped(issuer, order.hi, order.lo, order.kind);
  }
  // Records that the issuer has withdrawn an earlier commitment, with a reason code chosen by the institution.
  entry revoke(order: RevokeOrder signed by issuer)
    reads(issuer)
  {
    emit Revoked(issuer, order.hi, order.lo, order.reason);
  }
  // Lets the owner appoint a new authorised issuer, for example after a key rotation.
  entry set_issuer(order: IssuerOrder signed by owner)
    writes(issuer)
  {
    issuer = order.issuer;
    emit IssuerChanged(order.issuer);
  }
  event Stamped(issuer: Q_Address, hi: u128, lo: u128, kind: u64);
  event Revoked(issuer: Q_Address, hi: u128, lo: u128, reason: u64);
  event IssuerChanged(issuer: Q_Address);
}
