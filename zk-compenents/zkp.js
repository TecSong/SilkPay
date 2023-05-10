const snarkjs = require("snarkjs");
const ballot = require("./build/ballot.json");
const { sha256 } = require("crypto-hash");

async function generateProof(vote, merklePath, root) {
  const circuit = new snarkjs.Circuit(ballot);
  const witness = circuit.calculateWitness({
    vote: vote,
    merkle_path: merklePath,
    root: root,
  });
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    witness,
    circuit.vk
  );
  return {
    proof: proof,
    publicSignals: publicSignals,
  };
}

async function main() {
  const vote = [true];
  const leaf = sha256(Buffer.from(vote.map((b) => (b ? "1" : "0")).join("")));
  const merklePath = ["0000000000000000000000000000000000000000000000000000000000000000"];
  const root = "0000000000000000000000000000000000000000000000000000000000000000";
  const proof = await generateProof(vote, merklePath, root);
  console.log(proof);
}

main();
