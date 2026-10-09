# Qstamp Quanta Smart Contract Templates

These are example Quanta smart contracts for post quantum time stamping on the Quantova chain. They form a baseline that governments, financial institutions and other third parties can adopt together with the Qstamp SDK.

## Status

These contracts are published as examples. They are not certified for production use. Any organisation that deploys them must first commission an independent security audit by a qualified third party, review the contract against its own legal and regulatory obligations, and test it on the Quantova test network.

Quantova Inc provides the templates as a starting point and makes no warranty as to their fitness for a particular purpose. See the licence files for the full terms.

## Templates

1. `contracts/QStamp.qs` is the open template. Any account may anchor a 32 byte commitment and a record kind. The contract records the commitment together with the account that signed the transaction. It holds no state, no funds and no owner. This is the contract the Qstamp SDK uses by default, and the source in this repository compiles byte for byte to the contract deployed on the Quantova test network.

2. `contracts/QStampIssuer.qs` is the institutional template. Only an authorised issuer may anchor a commitment. Authority comes from a signature by the issuer over the order, verified by the contract itself, and the contract accepts the order only in a transaction sent by the issuer, so a copied order cannot be submitted by another account. The contract records each anchored commitment in its state. The issuer may record the withdrawal of a commitment that the contract anchored earlier, with a reason code, and the contract keeps that withdrawal in its state. The owner is the deploying account and the first issuer is named at deployment. The owner may propose a new issuer when keys are rotated, and the change takes effect only when the proposed issuer accepts it. Ownership passes in the same two steps.

3. `contracts/QStampCouncil.qs` is the multi party template. A commitment is anchored only when at least three of five officials approve it. To replace the officials, four of five approve a proposed set, which the contract records in full. After a waiting period of 24 hours and within the following seven days, all five proposed officials confirm the set and it takes effect. Any two of the current officials may cancel a pending replacement. The officials named at deployment take effect in the same way, once all five confirm them. This template suits public bodies where no single official may act alone.

## Cryptographic properties

Every transaction on the Quantova chain is signed with the Module Lattice Digital Signature Algorithm (FIPS 204, parameter set 65), and every block is finalised by validators who sign with the same algorithm. Signed orders and official approvals inside these contracts are verified with that algorithm as well. The chain has used post quantum signatures from its first block, so the record of who anchored what and when does not depend on any primitive that a quantum computer is known to break.

The chain admits only contract code signed by its attested compiler. A deployed template therefore cannot be replaced by altered code at the same address, and a reviewer can confirm that a deployment matches the reviewed source by compiling the source and comparing the resulting container.

Signed orders carry a nonce held by the contract, so an order that has been used once cannot be submitted again. Every order and every approval also carries a deadline in seconds since 1970, and the contract refuses it once the block time has passed that deadline. Every order and every approval also carries the domain value of the deployment, a random number fixed when the contract is deployed, and the contract refuses any order whose domain differs from its own, so an order made for one deployment cannot be used on another.

## How the Qstamp SDK works with these contracts

The Qstamp SDK computes a fingerprint of each record, combines each fingerprint with a random salt, arranges the results in a hash tree following RFC 9162, and derives a single 32 byte commitment that binds the chain, the contract, the signer, the record kind, the batch size and the tree root. Only that commitment reaches the chain. Each record receives a receipt that any party can verify against the record and the chain.

1. With the open template, the SDK performs every step. Install it with `npm install @quantovainc/qstamp` and call `stamp` and `verify`, or use the `qstamp` command line tool.

2. With the issuer template, the institution computes the commitment with the SDK and submits it from the issuer account as an order signed by the issuer through `@quantovainc/qcore`. The order carries the commitment twice, once as 32 bytes under which the contract records it and once as the two halves that appear in the recorded event, and both must be taken from the same commitment. The order also carries the domain value supplied when the contract was deployed, written as a decimal number. The fields must be listed in the order shown, which is the order in which the contract verifies the signature. The receipt is then verified with the SDK by naming the institution's contract and setting `trustCustomContract` to true. The following sequence follows the layout of the current template. The earlier layout was exercised on the Quantova test network.

```js
const qstamp = require('@quantovainc/qstamp');
const { Client, core } = require('@quantovainc/qcore');

const net = qstamp.NETWORKS.testnet;
const client = new Client(net.rpc, { expectedChainId: net.chainId });
const batch = qstamp.prepare([{ digest: qstamp.digestBytes(record) }]);
const issuer = core.address(seed, issuerIndex);
const kind = String(qstamp.KINDS.public_record);
const anchored = qstamp.commitment(batch.root, 1, { genesis: net.genesis, contract, sender: issuer, kind });
const deadline = String(Math.floor(Date.now() / 1000) + 600);
const domain = String(deploymentDomain);

const half = (b) => ((BigInt('0x' + b.subarray(8, 16).toString('hex')) << 64n) | BigInt('0x' + b.subarray(0, 8).toString('hex'))).toString();
await client.callSignedOrder(seed, issuerIndex, contract, '1effe529', {
  schemeOff: 152, ptrOff: 160, regionOff: 224,
  fields: [
    { offset: 120, width: 32, value: anchored.toString('hex') },
    { offset: 168, width: 8, value: domain },
    { offset: 176, width: 8, value: deadline },
    { offset: 184, width: 16, value: half(anchored.subarray(0, 16)) },
    { offset: 200, width: 16, value: half(anchored.subarray(16, 32)) },
    { offset: 216, width: 8, value: kind },
  ],
}, seed, issuerIndex, 2000000, '1000000');

const result = await qstamp.verify(receipt, { bytes: record, contract, trustCustomContract: true });
```

The receipt is assembled from the batch, the transaction identifier, the block height, the block identifier and the block time, in the format described in the Qstamp SDK documentation. The contract accepts the order only in a transaction sent by the issuer, so the signer of the transaction and the issuer recorded by the contract are always the same account, as SDK verification requires.

A withdrawal is submitted in the same way with selector `5add7204`, scheme offset 152, pointer offset 160 and region offset 192. Its fields are the commitment at offset 120 with width 32, the domain at offset 168, the deadline at offset 176 and the reason at offset 184, in that order. The reason code must not be zero, and only a commitment that the contract anchored earlier and has not yet withdrawn can be withdrawn.

A stamp uses about 1.7 million units of meter and a withdrawal about 1.9 million, because each records the commitment in contract state. A meter limit of 2000000 for a stamp and 2200000 for a withdrawal leaves a margin, and a maximum fee of 1000000 Quon covers both at the current test network rate.

3. With the council template, approvals from several officials must be collected and assembled into the call. Each stamp order names the account that will submit it, and the contract records that account as the signer of the commitment, so the commitment must be computed with that account as its sender. A council stamp can then be verified with the SDK in the same way as an issuer stamp. The contract also records the positions of the approving officials and the number of the set of officials in which they served. A council stamp uses about 1.4 million units of meter, arming a replacement about 5.6 million, confirming it about 6.3 million and cancelling it about 1.1 million. The published Quantova client libraries do not yet build quorum approvals, so this template has been exercised in the Quantova virtual machine but not yet on the test network. It must be tested in full before any use.

## Building and deploying

1. Compile a template with the Quanta command line tool or in the Quantova web IDE at qdock.io. The compiler returns the container, its interface and the selectors of every entry and event.

2. Have the container signed by the Quantova attested compiler, which the web IDE does on compilation. The chain refuses any container without that signature.

3. Deploy the signed container from the account that should become the owner, using the Quantova command line tool or the web IDE with the QMask wallet. For the issuer template, supply the address of the first issuer and a domain value as deployment parameters. A separate issuer key is recommended, so that the owner key can be kept offline. For the council template, supply the five official addresses and a domain value as deployment parameters. The domain value must be a fresh random 64 bit number other than zero for every deployment. A contract address depends only on the deploying account and its count of transactions, so after a relaunch of the network or on a fork a new deployment can receive the address of an earlier one, and only a fresh domain value ensures that orders and approvals signed for the earlier deployment are refused by the new one. Deploying the issuer template uses about 3.2 million units of meter and deploying the council template about 9.3 million. The council becomes active when all five officials confirm the set, no earlier than 24 hours and no later than eight days after deployment. A council that is not confirmed within that period must be deployed again.

4. Record the contract address, publish it to the parties who will verify receipts, and keep it under change control.

## Use with artificial intelligence systems

Organisations that build or operate artificial intelligence systems face growing obligations to keep records that can be trusted years later. Qstamp and these templates support that work in the following ways.

1. Model releases. Stamp the files of each model version and the manifest of its training data on the day of release, so that the version used for any later decision can be proven.

2. Decisions and actions. Collect the records of decisions or actions taken by automated systems, for example credit decisions, fraud alerts, trades or tool calls made by autonomous software, and stamp them in batches at a fixed interval. One transaction can carry up to 1048576 records.

3. Generated content. Stamp generated text, images or audio together with their provenance labels, so that an original can later be distinguished from an altered copy.

4. Evaluation results. Stamp test and safety evaluation results before a system is released, so that they cannot be changed afterwards.

A business that offers automated systems to clients can deploy the issuer template under its own key, give each client the contract address, and hand each client the receipts for the records that concern them. Each client can then verify those receipts independently.

## Security considerations

1. A transaction that calls a template without the required authority is still included in a block and still pays its fee, but the contract records nothing. A verifier must therefore require the recorded event and must never treat a final transaction alone as proof of a stamp. The Qstamp SDK applies this rule.

2. A receipt shows that a record existed unchanged no later than a stated time. It does not show that the record is true or lawful, and it does not identify a person. Linking a chain address to an organisation is a separate attestation.

3. Block time is set by the proposing validator in whole seconds and is accepted only when it is no more than 15 seconds ahead of the clocks of the other validators and not earlier than the previous block.

4. In this release the SDK confirms chain facts through an RPC endpoint. Verifiers should use the official endpoint or several independently operated endpoints until receipts carry finality certificates for fully offline verification.

5. Receipts hold the fingerprint and salt of each record and should be handled with the same care as the records themselves.

6. Test network deployments carry no evidential weight. Production deployments follow the Quantova main network.

## Licence

These templates are created and owned by Quantova Inc. They are licensed under the Apache License 2.0 or the MIT licence, at your option. The full texts are in the files `LICENSE-APACHE` and `LICENSE-MIT`, and the notice is in `NOTICE`.
