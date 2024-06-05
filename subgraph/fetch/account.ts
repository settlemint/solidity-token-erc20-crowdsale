import { Address, Bytes } from '@graphprotocol/graph-ts';
import { Account } from '../../generated/schema';

export function fetchAccount(address: Address): Account {
  const account = new Account(Bytes.fromHexString(address.toHex()));
  account.save();
  return account;
}
