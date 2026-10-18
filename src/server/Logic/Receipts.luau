--!strict
-- Idempotent Robux receipts (GDD §22.2 F-SEC-04), as a pure step StoreService's ProcessReceipt runs: a purchase id is
-- granted once (the grant and its id land in the profile together), and the purchase only counts as granted once a
-- save of the profile holding both succeeded. A retry after a failed save never grants again; it only saves again.
-- Implements: F-SEC-04.

local ProfileSchema = require(script.Parent.ProfileSchema)

local Receipts = {}

-- Returns true when the purchase may be reported PurchaseGranted, false for NotProcessedYet (Roblox retries).
function Receipts.process(
	data: { [string]: any },
	purchaseId: string,
	keep: number,
	grant: () -> (),
	save: () -> boolean
): boolean
	if ProfileSchema.addReceipt(data, purchaseId, keep) then
		grant()
	end
	return save()
end

return Receipts
