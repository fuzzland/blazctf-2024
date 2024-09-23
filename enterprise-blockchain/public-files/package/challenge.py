import ast
import asyncio
import typing

from anvil import AnvilInstance
from config import CONFIG


class ChallengeInstance(AnvilInstance):
    async def list_array(
        self, block_number, address, count_sig, element_sig
    ) -> typing.List[str]:
        count = int(
            ast.literal_eval(
                await self.call(
                    address,
                    count_sig,
                    block_number=block_number,
                )
            )
        )

        result = await asyncio.gather(
            *[
                self.call(
                    address,
                    element_sig,
                    str(i),
                    block_number=block_number,
                )
                for i in range(count)
            ]
        )
        return result

    async def check_solve(self):
        lock_f = self.lock("lock")
        if lock_f is None:
            return {"error": "no race condition"}
        with lock_f:
            block_number = await self.get_block_number()
            bridge_balance = await self.get_balance(block_number, CONFIG['L2_TOKEN'], CONFIG['BRIDGE'])

            if bridge_balance < 90 * 1e18:
                return {"message": f"flag: {CONFIG['flag']}"}
            return {"message": f"Bridge balance >= 90 FTT: {bridge_balance // 1e18}"}

    async def get_balance(
        self, block_number: int, token_address: str, address: str
    ) -> typing.Tuple[str, int, int, int]:
        result = await self.call(
            token_address,
            "balanceOf(address)",
            address,
            block_number=block_number,
        )
        return int(result.strip(), 0)
