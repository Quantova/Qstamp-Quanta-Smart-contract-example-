# Qstamp Quanta Smart Contract Templates

These are example Quanta smart contracts for post quantum time stamping on the Quantova chain. They form a baseline that governments, financial institutions and other third parties can adopt together with the Qstamp SDK.

## Status

These contracts are published as examples. They are not certified for production use. Any organisation that deploys them must first commission an independent security audit by a qualified third party, review the contract against its own legal and regulatory obligations, and test it on the Quantova test network.

Quantova Inc provides the templates as a starting point and makes no warranty as to their fitness for a particular purpose. See the licence files for the full terms.

## Ownership and regulatory notice

Quantova Inc, a corporation incorporated in the State of Delaware with its registered office at 1000 N. West Street, Suite 1501, Wilmington, Delaware 19801, United States, owns the Quantova infrastructure, the Quanta smart contract language and compiler, the Quantova Virtual Machine, the Qstamp software and these contract templates, together with all related intellectual property. Research is carried out for Quantova Inc by Quanto Organisation Pte. Ltd., registered in Singapore under Unique Entity Number 202544180C.

Quantova is a registered trademark of Quantova Inc. Qstamp, Quanta and QVM are trademarks of Quantova Inc. The open source licences described below grant rights in the source code only and grant no right to use these names or marks.

The templates produce evidence that supports record keeping obligations such as automatic event logging under Articles 12 and 19 of Regulation (EU) 2024/1689, tamper evident retention of broker dealer records under SEC Rule 17a 4 and the integrity requirement of Article 5(1)(f) of the UK GDPR. A receipt produced through these contracts is not a qualified electronic time stamp under Regulation (EU) 2024/1183 unless it is issued by a certified qualified trust service provider. Each organisation that deploys a template remains responsible for meeting the full requirements of the laws that apply to it.

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

## Benchmark reports

The following reports were produced on the Quantova test network `Q-test-net-1` on 9 October 2026 with Qstamp SDK release 0.1.3 and qcore 0.4.2. Every figure was measured on the live network. Test network receipts carry no evidential weight and the figures are given so that institutions can assess the design before an independent audit.

### Report 1. Batch stamping through the open contract

Agent actions were written as canonical JSON records, fingerprinted with SHA3 256, aggregated in one hash tree per batch and anchored in one transaction through `QStamp.qs` with the record kind `ai_agent_action`. One receipt from each batch was then verified against its record, and again against an altered copy of the record.

| Records in batch | Hash and tree time | Submit to final | Fee for the batch | Fee per record | Proof length | Receipt size | Verification | Altered record |
|---|---|---|---|---|---|---|---|---|
| 1 | 10 ms | 0.66 s | 0.005 TQTOV | 0.005 TQTOV | 0 hashes | 773 bytes | valid | invalid |
| 16 | 2 ms | 0.67 s | 0.005 TQTOV | 0.0003125 TQTOV | 4 hashes | 1041 bytes | valid | invalid |
| 256 | 8 ms | 0.76 s | 0.005 TQTOV | 0.0000195 TQTOV | 8 hashes | 1312 bytes | valid | invalid |
| 4096 | 74 ms | 0.88 s | 0.005 TQTOV | 0.0000012 TQTOV | 12 hashes | 1582 bytes | valid | invalid |
| 65536 | 984 ms | 2.84 s | 0.005 TQTOV | 0.00000008 TQTOV | 16 hashes | 1852 bytes | valid | invalid |

The fee is constant per transaction whatever the size of the batch, the proof grows with the base two logarithm of the batch size and a single receipt stays below two kilobytes. The 70161 records of this report cost 0.025 TQTOV in total.

### Report 2. Autonomous agent smoke test

A credit decision agent and an order execution agent were simulated. The credit agent produced two batches of six decisions, the execution agent one batch of five orders, and a model passport was stamped with the record kind `ai_model`. All four transactions were final in about 0.7 seconds each and cost 0.02 TQTOV in total. The fourth credit decision was then presented as it would be to a court. Its receipt verified as valid on all eight checks, which are format, contract, content, inclusion, chain, transaction, event and block. The same record with the loan amount raised by 1000 was reported invalid because its content no longer matched the fingerprint.

| Item | Value |
|---|---|
| Record fingerprint | `efb393903da28c2a6221179be662a2bbe2be06dfbd1acdee26bb057b6d2fb11f` |
| Batch root | `34f64b12e5b363f1add6c48c0f85ebd60e4c2d421e5559f5d7b88717db205c54` |
| Commitment recorded on chain | `6068a3e9625471530eda32f3292a9ac667c4f543281d62b12c62ad3481f07e0a` |
| Transaction | `QTX1V53JW528S64SZYD6EDZ563N0PUUA2ARGNQHV4LTJMNH24PQS5VPQTAH8RQ` |
| Block | 2011753 |

### Report 3. Deployment and operation of the issuer and council templates

The current templates were compiled through the attested Quanta compiler, checked against the audited container hashes and deployed with a fresh random deployment domain. The issuer template passed every live check, and the council template passed its deployment and early activation checks. The council stamp and quorum checks follow once its 24 hour activation delay has passed.

| Live check on the test network | Result |
|---|---|
| Compiled container matches the audited container | pass |
| Issuer stamp sent by the issuer records the Stamped event | pass |
| SDK verification of the issuer stamp with `trustCustomContract` | valid |
| Signed order copied and sent by another account | refused |
| Order past its deadline | refused |
| Order signed for another deployment domain | refused |
| Revocation of a commitment never stamped | refused |
| Revocation of a stamped commitment records Revoked | pass |
| Issuer change by proposal and acceptance | pass |
| Former issuer stamps after the change | refused |
| Owner change by proposal and acceptance | pass |
| Owner proposal by an account that is not the owner | refused |
| Council deployment with five officials | pass |
| Council activation before 24 hours | refused |

| Entry | Approximate meter |
|---|---|
| Open template stamp | 11190 |
| Issuer stamp | 1675288 |
| Issuer revocation | 1901217 |
| Issuer change proposal | 537161 |
| Issuer or owner acceptance | 767756 |
| Council stamp with three of five approvals | 1414617 |
| Council replacement armed | 5572968 |
| Council replacement confirmed | 6320975 |

The issuer and council suites used 16.14 TQTOV in total, almost all of it for the two deployments.

### Report 4. What a stored agent fingerprint looks like

The record never leaves the operator. The operator keeps the record and its receipt, and the chain keeps only the commitment. The example below is record 128 of the 256 record batch in Report 1.

The agent action, held by the operator.

```json
{"agent":"superintelligence-agent-0","decision":"execute","input_digest":"275e435ad3576f85435bf41336a402a539482abaec358740eccc72b796e94d93","model":"agent-model 4.0.0","operator":"Benchmark Operator","output_digest":"52d523238d70c57bc90212705860004a9c0358ffbaea2ea328295405ee34c826","seq":128,"time":"2026-10-09T10:42:54.447Z","tool":"payments.approve"}
```

The receipt, held by the operator next to the record.

```json
{
  "format": "qstamp-receipt/1",
  "chain": { "id": "Q-test-net-1", "genesis": "ca91e093bb8de33e90db52d7c89876597d14760703793ea7211929e73e613062" },
  "contract": "Q1D6TZFRL203P3DFAFVUPZUHGUCM4EWGH6063XNS42VA5235RNQWXS7FXEWX",
  "kind": "6",
  "record": {
    "alg": "sha3-256",
    "digest": "64d3f00a654a9b5ff82dd02cb53538400da7c6ef553b1ab136489d52e7ac9525",
    "salt": "68b5bf8bd78be70124acbfd5313a6d343c08744ec75da4e2ef4f6e281b5399ac"
  },
  "proof": {
    "index": 128,
    "size": 256,
    "path": [
      "a49b2f53e7788c42f8cf127cdec04d4c74594bc1dd752c4434824590ec91e243",
      "fb227360f5bc9b8c5004d6c2bb6c5ee640378123ab861a2f7bd2f52064c7ee37",
      "c78c09dd344409bd1a8f33d7b384753236af33419cc3f7046eb7aa137424a3e9",
      "a134048303f7ec56a00ca7bcee2db42f4841c7941924b3c807dba1db564eedc2",
      "2737e5a564e6c6859f754fcb03c15e9d6168497c78976b23e3039e1d4a863035",
      "c259a6b388a85e3322eae14849a9550f5bc24c6462c65b1a87590051741341fa",
      "f38ea654196873cfc4569a513b6ab4ed883d9911b5152b48fc5cec7ed7f43550",
      "af4a75b116928f621e8effa3a84176cf82b80d2a258055f50a2af3e17c58f86d"
    ]
  },
  "root": "79c81ea710d8ac4291a90e5d6fe8b1d00380807a7218e971f98fb8d0fc632b7a",
  "anchor": {
    "tx": "QTX1TWK6KUEU0FM8KJ0UU0L8JQSTX99S5XQL6967PUHFULWKPV900R8S8RMRM2",
    "height": 2030475,
    "block": "QBK1NW9JPXMEU8Z0HREN5HV4GK5PAW5738RZGDNN9E63Q2AAG3GRCCPQG29KKC",
    "time": 1791542574,
    "sender": "Q1NUR6ETECQXEVE77TJ9YPZ6WAWYMT45WCJANV5J43X93SF79DWE0S0D572X"
  }
}
```

The event recorded on chain by `QStamp.qs` in block 2030475. Its data is the 32 byte signing account `9f07acaf…f8ad765f`, then the 32 byte commitment `f67c473e…c1ccf1a6`, then the record kind 6 as an eight byte integer.

```json
{
  "contract": "Q1D6TZFRL203P3DFAFVUPZUHGUCM4EWGH6063XNS42VA5235RNQWXS7FXEWX",
  "selector": "5a110849",
  "data": "9f07acaf3801b2ccfbcb91481169dd7136bad1d89766ca4ab1316304f8ad765ff67c473ec64644091aeada49ff2a8de2a497673b725ab12ff9ea32a7c1ccf1a60000000000000006"
}
```

A verifier recomputes the fingerprint of the record, the leaf with the salt, the root with the eight path hashes and the commitment with the chain, contract, sender, kind and batch size, and confirms that the commitment equals the one in the event. Any change to the record, the receipt or the event makes the result invalid.

### Report 5. Security review

| Review | Scope | Result |
|---|---|---|
| Contract review in the Quantova Virtual Machine | All three templates, original and current versions | 337 checks as expected, 0 unexpected |
| Live test network run | Issuer and council templates | all checks passed |
| Deployed open contract | `QStamp.qs` source against the deployed container | identical byte for byte |
| SDK review | Qstamp SDK 0.1.3 and its published package | no critical or high findings, all fixable findings resolved |

These reviews were carried out internally by Quantova Inc. An independent security audit by a qualified third party is required before any template is used in production.

## Security considerations

1. A transaction that calls a template without the required authority is still included in a block and still pays its fee, but the contract records nothing. A verifier must therefore require the recorded event and must never treat a final transaction alone as proof of a stamp. The Qstamp SDK applies this rule.

2. A receipt shows that a record existed unchanged no later than a stated time. It does not show that the record is true or lawful, and it does not identify a person. Linking a chain address to an organisation is a separate attestation.

3. Block time is set by the proposing validator in whole seconds and is accepted only when it is no more than 15 seconds ahead of the clocks of the other validators and not earlier than the previous block.

4. In this release the SDK confirms chain facts through an RPC endpoint. Verifiers should use the official endpoint or several independently operated endpoints until receipts carry finality certificates for fully offline verification.

5. Receipts hold the fingerprint and salt of each record and should be handled with the same care as the records themselves.

6. Test network deployments carry no evidential weight. Production deployments follow the Quantova main network.

## Licence

Copyright 2026 Quantova Inc. These templates are created and owned by Quantova Inc. They are licensed under the Apache License 2.0 or the MIT licence, at your option, and every source file carries the identifier `SPDX-License-Identifier: Apache-2.0 OR MIT`. The full texts are in the files `LICENSE-APACHE` and `LICENSE-MIT`, and the notice is in `NOTICE`.

Anyone who redistributes these templates or a modified version must keep the copyright notice of Quantova Inc, the `NOTICE` file and the licence text, and must mark every modified file with a prominent notice stating that it was changed. A modified version must not be presented as an official Quantova template, and the licences grant no right to use the Qstamp, Quantova, Quanta or QVM names or marks.
