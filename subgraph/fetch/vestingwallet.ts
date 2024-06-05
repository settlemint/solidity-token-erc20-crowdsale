import { Address, BigInt } from '@graphprotocol/graph-ts';
import { VestingWalletContract } from '../../generated/schema';
import { VestingWallet } from '../../generated/vestingwallet/VestingWallet';
import { fetchAccount } from './account';

export function fetchVestingWallet(address: Address): VestingWalletContract {
  const account = fetchAccount(address);
  let contract = VestingWalletContract.load(account.id.toHex());

  if (contract == null) {
    const endpoint = VestingWallet.bind(address);
    const start = endpoint.try_start();
    const duration = endpoint.try_duration();
    contract = new VestingWalletContract(account.id.toHex());

    contract.start = start.reverted ? null : start.value;
    contract.duration = duration.reverted ? null : duration.value;
    contract.erc20Released = BigInt.fromString('0');
    contract.etherReleased = BigInt.fromString('0');

    account.asVestingWallet = contract.id;
    contract.asAccount = account.id;
  }

  contract.save();
  account.save();

  return contract as VestingWalletContract;
}
