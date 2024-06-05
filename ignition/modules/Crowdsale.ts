import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const CrowdsaleModule = buildModule('CrowdsaleModule', (m) => {
  const owner = m.getAccount(0);
  const token = m.contract('ExampleToken', [
    'ExampleToken',
    'ET',
    BigInt(5000_000000000000000000),
    owner,
  ]);

  const duration = 60 * 60 * 24 * 365;
  const timestamp = Date.now();
  const vestingWallet = m.contract('ExampleVestingWallet', [
    owner,
    timestamp,
    duration,
  ]);

  const vestingvault = m.contract('ExampleVestingVault', [token]);

  const daysToAdd = 30;
  const resultDate = new Date(timestamp + daysToAdd * 24 * 60 * 60 * 1000);

  const pricefeed = '0x694AA1769357215DE4FAC081bf1f309aDC325306'; //ETH-USD on Sepolia
  const crowdsale = m.contract('ExampleCrowdSale', [
    pricefeed,
    token,
    owner,
    250,
    resultDate.getTime(),
    vestingvault,
  ]);
  return { token, vestingWallet, vestingvault, crowdsale };
});

export default CrowdsaleModule;
