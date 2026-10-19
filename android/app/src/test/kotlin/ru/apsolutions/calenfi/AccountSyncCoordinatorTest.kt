package ru.apsolutions.calenfi

import org.junit.Assert.assertEquals
import org.junit.Test

class AccountSyncCoordinatorTest {
    @Test fun uiWaitsForBackgroundAndOtherAccountsProceed() {
        val guard = AccountSyncCoordinator()
        val background = Any()
        val ui = Any()
        val grants = mutableListOf<String>()
        guard.acquire("a", background, "bg") { grants.add("bg") }
        guard.acquire("a", ui, "ui") { grants.add("ui") }
        guard.acquire("b", ui, "other") { grants.add("other") }
        assertEquals(listOf("bg", "other"), grants)
        guard.release("a", background, "bg")
        assertEquals(listOf("bg", "other", "ui"), grants)
    }

    @Test fun staleReleaseCannotUnlockAnotherPass() {
        val guard = AccountSyncCoordinator()
        val host = Any()
        val grants = mutableListOf<String>()
        guard.acquire("a", host, "first") { grants.add("first") }
        guard.acquire("a", host, "second") { grants.add("second") }
        guard.acquire("a", host, "third") { grants.add("third") }
        guard.release("a", Any(), "first")
        assertEquals(listOf("first"), grants)
        guard.release("a", host, "first")
        guard.release("a", host, "first")
        assertEquals(listOf("first", "second"), grants)
        guard.release("a", host, "second")
        assertEquals(listOf("first", "second", "third"), grants)
    }

    @Test fun stoppingWorkerDropsItsWaitersAndTransfersOwnership() {
        val guard = AccountSyncCoordinator()
        val worker = Any()
        val ui = Any()
        val grants = mutableListOf<String>()
        guard.acquire("a", worker, "bg") { grants.add("bg") }
        guard.acquire("a", worker, "obsolete") { grants.add("obsolete") }
        guard.acquire("a", ui, "ui") { grants.add("ui") }
        guard.dropOwner(worker)
        assertEquals(listOf("bg", "ui"), grants)
        guard.dropOwner(worker)
        assertEquals(listOf("bg", "ui"), grants)
    }
}
