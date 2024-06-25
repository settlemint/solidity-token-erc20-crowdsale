import { events, transactions } from '@amxx/graphprotocol-utils';
import { Bytes } from '@graphprotocol/graph-ts';
import { VestingLockedIn, VestingReleased } from '../../generated/schema';
import { VestingLockedIn as VestingLockedInEvent } from '../../generated/vestingvault/IVestingVault';
import { fetchAccount } from '../fetch/account';
import { fetchVesting, fetchVestingVault } from '../fetch/vestingvault';

export function handleVestingLockedIn(event: VestingLockedInEvent): void {
  const contract = fetchVestingVault(event.address);
  const beneficiary = fetchAccount(event.params.beneficiary);
  const vesting = fetchVesting(contract, beneficiary, event.params.releaseTime);

  const ev = new VestingLockedIn(events.id(event));

  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.beneficiary = beneficiary.id;
  ev.tokenAmount = event.params.tokenAmount;
  ev.releaseTime = event.params.releaseTime;

  vesting.tokenAmount = vesting.tokenAmount.plus(event.params.tokenAmount);

  vesting.save();
  ev.save();
}

export function handleVestingReleased(event: VestingLockedInEvent): void {
  const contract = fetchVestingVault(event.address);
  const beneficiary = fetchAccount(event.params.beneficiary);
  const vesting = fetchVesting(contract, beneficiary, event.params.releaseTime);

  const ev = new VestingReleased(events.id(event));

  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.beneficiary = beneficiary.id;
  ev.tokenAmount = event.params.tokenAmount;

  vesting.tokenAmount = vesting.tokenAmount.minus(event.params.tokenAmount);

  vesting.save();
  ev.save();
}
