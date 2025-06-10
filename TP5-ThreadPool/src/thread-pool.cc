/**
 * File: thread-pool.cc
 * --------------------
 * Presents the implementation of the ThreadPool class.
 */

#include "thread-pool.h"
using namespace std;

ThreadPool::ThreadPool(size_t numThreads) : 
    wts(numThreads), done(false), taskSem(0), activeTasks(0), waitSem(0), allTasksComplete(true) {
    
    // Initialize workers
    for (size_t i = 0; i < numThreads; ++i) {
        wts[i].available = true;
        wts[i].ts = thread([this, i] { worker(i); });
    }
    
    // Start dispatcher thread
    dt = thread([this] { dispatcher(); });
}

void ThreadPool::schedule(const function<void(void)>& thunk) {
    // Add task to queue
    {
        lock_guard<mutex> lg(queueLock);
        tasks.push(thunk);
    }
    
    // Increment active tasks counter (separate lock)
    {
        lock_guard<mutex> activeLg(activeTasksMtx);
        activeTasks++;
        allTasksComplete = false; // Set flag to indicate tasks are pending
    }
    
    // Notify dispatcher that there's a new task
    taskSem.signal();
}

void ThreadPool::worker(int id) {
    while (true) {
        // Wait for a task to be assigned to this worker
        wts[id].sem.wait();
        
        // If the thread pool is shutting down, exit the loop
        if (done) break;
        
        // Execute the assigned task
        wts[id].thunk();
        
        // Mark this worker as available again
        {
            lock_guard<mutex> lg(wts[id].mtx);
            wts[id].available = true;
        }
        
        // Update the active tasks counter and signal if all tasks are complete
        {
            lock_guard<mutex> activeLg(activeTasksMtx);
            activeTasks--;
            
            // If no active tasks remain, set the flag and signal waiting threads
            if (activeTasks == 0) {
                allTasksComplete = true;
                waitSem.signal();
            }
        }
    }
}

void ThreadPool::dispatcher() {
    while (true) {
        // Wait for new tasks
        taskSem.wait();
        
        // Check if we're shutting down and no more tasks
        if (done) {
            lock_guard<mutex> lg(queueLock);
            if (tasks.empty()) break;
        }
        
        // Get the next task (if available)
        function<void(void)> task;
        bool hasTask = false;
        {
            lock_guard<mutex> lg(queueLock);
            if (!tasks.empty()) {
                task = tasks.front();
                tasks.pop();
                hasTask = true;
            }
        }
        
        // If no task available, continue (this shouldn't happen normally)
        if (!hasTask) continue;
        
        // Find an available worker
        bool assigned = false;
        while (!assigned) {
            for (auto& wt : wts) {
                lock_guard<mutex> lg(wt.mtx);
                if (wt.available) {
                    wt.available = false;
                    wt.thunk = task;
                    wt.sem.signal();
                    assigned = true;
                    break;
                }
            }
            
            // If no worker available, yield and try again
            if (!assigned) {
                this_thread::yield();
            }
        }
    }
    
    // Notify all workers to shutdown
    for (auto& wt : wts) {
        wt.sem.signal();
    }
}

// void ThreadPool::wait() {
//     while (true) {
//         // Check if all tasks are done while holding the lock
//         {
//             lock_guard<mutex> activeLg(activeTasksMtx);
//             if (activeTasks == 0) return;
            
//             // Reset semaphore to avoid spurious wakeups
//             // (This is a simplified approach - a condition variable would be better)
//         }
        
//         // Wait for completion signal
//         waitSem.wait();
        
//         // After waking up, check again (loop will check activeTasks)
//     }
// }

void ThreadPool::wait() {
    while (true) {
        {
            // Check if all tasks are done while holding the lock
            lock_guard<mutex> activeLg(activeTasksMtx);
            if (allTasksComplete) return;
        }
        
        waitSem.wait();
        // After waking up, check again (loop will check activeTasks)
    }
}


ThreadPool::~ThreadPool() {
    // Wait for all currently scheduled tasks to complete
    wait();
    
    // Set done flag
    done = true;
    
    // Notify dispatcher to wake up and check done flag
    taskSem.signal();
    
    // Wait for dispatcher to finish
    if (dt.joinable()) dt.join();
    
    // Wait for all workers to finish
    for (auto& wt : wts) {
        if (wt.ts.joinable()) wt.ts.join();
    }
}