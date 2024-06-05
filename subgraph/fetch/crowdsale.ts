import { Address, BigInt } from '@graphprotocol/graph-ts';
import { fetchERC20 } from '@openzeppelin/subgraphs/src/fetch/erc20';
import { ICrowdSale } from '../../generated/crowdsale/ICrowdSale';
import { CrowdSaleContract } from '../../generated/schema';
import { fetchAccount } from './account';

export function fetchCrowdSaleContract(
  address: Address,
  tokenAmount: BigInt
): CrowdSaleContract {
  const account = fetchAccount(address);
  let contract = CrowdSaleContract.load(account.id.toHex());

  if (contract == null) {
    const endpoint = ICrowdSale.bind(address);
    const token = endpoint.try_token();
    const wallet = endpoint.try_wallet();
    const tokensAvailable = endpoint.try_tokensAvailable();
    contract = new CrowdSaleContract(account.id.toHex());

    contract.token = token.reverted ? null : fetchERC20(token.value).id;
    contract.wallet = wallet.reverted ? null : fetchAccount(wallet.value).id;
    contract.initialSupply = tokensAvailable.reverted
      ? null
      : tokensAvailable.value.plus(tokenAmount);
    contract.tokensAvailable = tokensAvailable.reverted
      ? null
      : tokensAvailable.value.plus(tokenAmount);
    contract.fundsRaised = BigInt.fromString('0');
    account.asCrowdSale = contract.id;

    contract.save();
    account.save();
  }

  return contract as CrowdSaleContract;
}
