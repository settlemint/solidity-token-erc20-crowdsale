import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const CrowdsaleModule = buildModule('CrowdsaleModule', (m) => {
  const owner = m.getAccount(0);
  const token = m.contract('ExampleToken', [
    'ExampleToken',
    'ET',
    5000 * 1e18,
    owner,
  ]);

  return { token };
});

export default CrowdsaleModule;
