pragma circom 2.1.4;

include "libsnark/circuits/poseidon/poseidon_gen.mir";

template VoteCircuit() {
  signal vote[2];
  signal secret_key;
  signal public_key[2];
  signal encrypted_vote[2];

  // Hash the secret key to generate the public key
  public_key[0] <== poseidon([secret_key]);
  public_key[1] <== poseidon([public_key[0]]);

  // Encrypt the vote using the public key
  encrypted_vote[0] <== public_key[0] * vote[0];
  encrypted_vote[1] <== public_key[1] * vote[1];

  // Verify that the encrypted vote matches the public key
  enforce public_key[0] * encrypted_vote[1] == public_key[1] * encrypted_vote[0];
}

component main = VoteCircuit();
