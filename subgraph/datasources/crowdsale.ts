import { events, transactions } from '@amxx/graphprotocol-utils';
import { BigInt, Bytes } from '@graphprotocol/graph-ts';
import { TokensPurchased as TokensPurchasedEvent } from '../../generated/crowdsale/ICrowdSale';
import { CrowdSaleTokenPurchase } from '../../generated/schema';
import { fetchAccount } from '../fetch/account';
import { fetchCrowdSaleContract } from '../fetch/crowdsale';

export function handleTokensPurchased(event: TokensPurchasedEvent): void {
  const contract = fetchCrowdSaleContract(event.address, event.params.amount);
  const purchaser = fetchAccount(event.params.purchaser);
  const beneficiary = fetchAccount(event.params.beneficiary);
  const ev = new CrowdSaleTokenPurchase(events.id(event));

  ev.emitter = Bytes.fromHexString(contract.id);
  ev.transaction = transactions.log(event).id;
  ev.timestamp = event.block.timestamp;

  ev.contract = contract.id;
  ev.purchaser = purchaser.id;
  ev.beneficiary = beneficiary.id;
  ev.tokenAmount = event.params.amount;
  ev.weiValue = event.params.value;

  if (contract.tokensAvailable) {
    const tokensAvailable = contract.tokensAvailable as BigInt;
    contract.tokensAvailable = tokensAvailable.minus(event.params.amount);
  }

  if (contract.fundsRaised) {
    const fundsRaised = contract.fundsRaised as BigInt;
    contract.fundsRaised = fundsRaised.plus(event.params.value);
  }

  ev.save();
  contract.save();
}
