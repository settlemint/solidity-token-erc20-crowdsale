import { constants } from '@amxx/graphprotocol-utils';
import { Address, BigInt } from '@graphprotocol/graph-ts';
import { fetchERC20 } from '@openzeppelin/subgraphs/src/fetch/erc20';
import { Account, Vesting, VestingVaultContract } from '../../generated/schema';
import { IVestingVault } from '../../generated/vestingvault/IVestingVault';
import { fetchAccount } from './account';

export function fetchVestingVault(address: Address): VestingVaultContract {
  const account = fetchAccount(address);
  let contract = VestingVaultContract.load(account.id.toHex());

  if (contract == null) {
    const endpoint = IVestingVault.bind(address);
    const token = endpoint.try_token();
    contract = new VestingVaultContract(account.id.toHex());

    contract.token = token.reverted ? null : fetchERC20(token.value).id;
    contract.asAccount = account.id;
    account.asVestingVault = contract.id;

    contract.save();
    account.save();
  }

  return contract as VestingVaultContract;
}

export function fetchVesting(
  contract: VestingVaultContract,
  beneficiary: Account,
  releaseTime: BigInt
): Vesting {
  const id = contract.id
    .concat('/')
    .concat(beneficiary.id.toHex())
    .concat('/')
    .concat(releaseTime.toString());
  let vesting = Vesting.load(id);

  if (vesting == null) {
    vesting = new Vesting(id);
    vesting.contract = contract.id;
    vesting.beneficiary = beneficiary.id;
    vesting.releaseTime = releaseTime;
    vesting.tokenAmount = constants.BIGINT_ZERO;
    vesting.save();
  }

  return vesting as Vesting;
}
