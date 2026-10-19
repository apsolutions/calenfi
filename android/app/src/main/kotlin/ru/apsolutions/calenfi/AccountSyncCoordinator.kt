package ru.apsolutions.calenfi

/** Shared by UI and headless Flutter engines. Access only on the main thread. */
internal class AccountSyncCoordinator {
    private data class Request(val account: String, val owner: Any, val token: String, val grant: () -> Unit)
    private val holders = mutableMapOf<String, Request>()
    private val waiting = mutableListOf<Request>()

    fun acquire(account: String, owner: Any, token: String, grant: () -> Unit) {
        val request = Request(account, owner, token, grant)
        if (holders.containsKey(account)) {
            waiting.add(request)
        } else {
            holders[account] = request
            grant()
        }
    }

    fun release(account: String, owner: Any, token: String) {
        val holder = holders[account] ?: return
        if (holder.owner !== owner || holder.token != token) return
        holders.remove(account)
        advance(account)
    }

    fun dropOwner(owner: Any) {
        waiting.removeAll { it.owner === owner }
        val accounts = holders.filterValues { it.owner === owner }.keys.toList()
        accounts.forEach { holders.remove(it) }
        accounts.forEach { advance(it) }
    }

    private fun advance(account: String) {
        val index = waiting.indexOfFirst { it.account == account }
        if (index < 0) return
        val request = waiting.removeAt(index)
        holders[account] = request
        request.grant()
    }
}
