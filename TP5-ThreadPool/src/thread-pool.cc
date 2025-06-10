/**
 * File: thread-pool.cc
 * --------------------
 * Presents the implementation of the ThreadPool class.
 */

#include "thread-pool.h"
using namespace std;

ThreadPool::ThreadPool(size_t numThreads) : 
    wts(numThreads), done(false), taskSem(0), activeTasks(0) {
    
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
    
    // Increment active tasks counter
    {
        lock_guard<mutex> activeLg(activeTasksMtx);
        activeTasks++;
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
        
        // Mark this worker as available again and notify dispatcher
        {
            lock_guard<mutex> lg(wts[id].mtx);
            wts[id].available = true;
        }

        workerAvailable.signal();
        
        // Update the active tasks counter and notify waiting threads if needed
        {
            unique_lock<mutex> activeLg(activeTasksMtx);
            activeTasks--;
            
            // Use condition variable for wait() to prevent accumulation of signals and race conditions
            if (activeTasks == 0) {
                waitCV.notify_all(); // Notify all threads waiting in wait()
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
        
        // If no task available, continue
        if (!hasTask) continue;
        
        // Wait for worker availability
        bool assigned = false;
        while (!assigned) {
            // Try to find an available worker
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
            
            // If no worker available, wait for one to become available
            if (!assigned) {
                // Wait for a worker to signal availability
                workerAvailable.wait();
            }
        }
    }
    
    // Notify all workers to shutdown
    for (auto& wt : wts) {
        wt.sem.signal();
    }
}

void ThreadPool::wait() {
    // Use condition variable with proper synchronization
    unique_lock<mutex> activeLg(activeTasksMtx);
    while (activeTasks > 0) {
        waitCV.wait(activeLg); // Wait until activeTasks becomes 0
    }
    // Lock is automatically released when function exits
}

ThreadPool::~ThreadPool() {
    // Wait for all currently scheduled tasks to complete
    wait();
    
    // Set done flag
    done = true;
    
    // Notify dispatcher to wake up and check done flag
    taskSem.signal();
    
    // Wake up dispatcher if it's waiting for workers
    workerAvailable.signal();
    
    // Wait for dispatcher to finish
    if (dt.joinable()) dt.join();
    
    // Wait for all workers to finish
    for (auto& wt : wts) {
        if (wt.ts.joinable()) wt.ts.join();
    }
}