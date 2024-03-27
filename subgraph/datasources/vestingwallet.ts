import { events, transactions } from '@amxx/graphprotocol-utils';
import { Bytes } from '@graphprotocol/graph-ts';
import { fetchERC20 } from '@openzeppelin/subgraphs/src/fetch/erc20';
import { ERC20Released, EtherReleased } from '../../generated/schema';
import {
  ERC20Released as ERC20ReleasedEvent,
  EtherReleased as EtherReleasedEvent,
} from '../../generated/vestingwallet/VestingWallet';
import { fetchVestingWallet } from '../fetch/vestingwallet';

export function handleEtherReleased(event: EtherReleasedEvent): void {
  const contract = fetchVestingWallet(event.address);
  const ev = new EtherReleased(events.id(event));

  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.amount = event.params.amount;
  ev.from = Bytes.fromHexString(contract.id);
  ev.to = contract.beneficiary;

  contract.etherReleased = contract.etherReleased.plus(event.params.amount);

  ev.save();
  contract.save();
}

export function handleERC20Released(event: ERC20ReleasedEvent): void {
  const contract = fetchVestingWallet(event.address);
  const token = fetchERC20(event.params.token);
  const ev = new ERC20Released(events.id(event));

  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.amount = event.params.amount;
  ev.token = token.id;
  ev.from = Bytes.fromHexString(contract.id);
  ev.to = contract.beneficiary;

  contract.erc20Released = contract.erc20Released.plus(event.params.amount);

  ev.save();
  contract.save();
}
