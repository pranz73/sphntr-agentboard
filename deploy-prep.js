// AgentBoard deploy prep: build init code, estimate gas, verify Agent ID holding.
// Read-only + baw PREVIEW only (no execute). Run from ~/workspace/hackathon-agentboard.
'use strict';
const fs = require('fs');
const L = require('/home/hatch/workspace/fastmint/lib.js');
const { ethers } = L;

const WALLET = '0x797BDa81123a3d7b8673440e93A879b92e9fe941';
const AGENT_ID = '0x60b9262456de011f7d15a54cdd8c48baaa8b022f';

(async () => {
  const art = JSON.parse(fs.readFileSync(__dirname + '/out/AgentBoard.sol/AgentBoard.json', 'utf8'));
  const argEnc = ethers.AbiCoder.defaultAbiCoder().encode(['address'], [AGENT_ID]);
  const initCode = art.bytecode.object + argEnc.slice(2);
  fs.writeFileSync(__dirname + '/initcode.txt', initCode);
  console.log('initCode bytes:', (initCode.length - 2) / 2);
  console.log('constructor arg (decoded check):', ethers.AbiCoder.defaultAbiCoder().decode(['address'], '0x' + argEnc.slice(2))[0]);

  // Agent ID holding check (registration gate)
  const idIface = new ethers.Interface(['function balanceOf(address) view returns (uint256)']);
  const balRes = await L.rpc('eth_call', [{ to: AGENT_ID, data: idIface.encodeFunctionData('balanceOf', [WALLET]) }, 'latest']);
  console.log('AgentID balanceOf(wallet):', BigInt(balRes).toString());

  // Gas: estimate creation + current gas price + wallet BNB balance
  const [est, gp, bal] = await Promise.all([
    L.rpc('eth_estimateGas', [{ from: WALLET, data: initCode }, 'latest']),
    L.rpc('eth_gasPrice', []),
    L.rpc('eth_getBalance', [WALLET, 'latest']),
  ]);
  const estGas = BigInt(est), price = BigInt(gp), balWei = BigInt(bal);
  console.log('estimateGas (creation):', estGas.toString());
  console.log('gasPrice:', ethers.formatUnits(price, 'gwei'), 'gwei');
  console.log('est cost:', ethers.formatEther(estGas * price), 'BNB');
  console.log('wallet BNB:', ethers.formatEther(balWei));
  console.log('nonce:', await L.rpc('eth_getTransactionCount', [WALLET, 'latest']));
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
