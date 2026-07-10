package com.cloudmail.app

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.cloudmail.app.api.RetrofitClient
import com.cloudmail.app.databinding.ActivityMainBinding
import com.cloudmail.app.model.EmailListRequest
import com.cloudmail.app.utils.SharedPreferencesManager
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityMainBinding
    private lateinit var prefs: SharedPreferencesManager
    private lateinit var adapter: EmailAdapter
    private var currentPage = 1
    private var isLoading = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        prefs = SharedPreferencesManager(this)
        
        // Check if logged in
        if (prefs.token.isNullOrEmpty()) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }
        
        setupRecyclerView()
        setupSwipeRefresh()
        loadEmails()
        
        binding.btnAddUser.setOnClickListener {
            startActivity(Intent(this, AddUserActivity::class.java))
        }
    }
    
    private fun setupRecyclerView() {
        adapter = EmailAdapter()
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = adapter
        
        // Pagination
        binding.recyclerView.addOnScrollListener(object : androidx.recyclerview.widget.RecyclerView.OnScrollListener() {
            override fun onScrolled(recyclerView: androidx.recyclerview.widget.RecyclerView, dx: Int, dy: Int) {
                super.onScrolled(recyclerView, dx, dy)
                
                val layoutManager = binding.recyclerView.layoutManager as LinearLayoutManager
                val visibleItemCount = layoutManager.childCount
                val totalItemCount = layoutManager.itemCount
                val firstVisibleItemPosition = layoutManager.findFirstVisibleItemPosition()
                
                if (!isLoading && (visibleItemCount + firstVisibleItemPosition) >= totalItemCount 
                    && firstVisibleItemPosition >= 0) {
                    currentPage++
                    loadEmails()
                }
            }
        })
    }
    
    private fun setupSwipeRefresh() {
        binding.swipeRefresh.setOnRefreshListener {
            currentPage = 1
            loadEmails()
        }
        binding.swipeRefresh.setColorSchemeResources(
            android.R.color.holo_blue_bright,
            android.R.color.holo_green_light,
            android.R.color.holo_orange_light,
            android.R.color.holo_red_light
        )
    }
    
    private fun loadEmails() {
        if (isLoading) return
        
        isLoading = true
        showLoading(true)
        
        lifecycleScope.launch {
            try {
                val token = prefs.token ?: ""
                val request = EmailListRequest(
                    num = currentPage,
                    size = 20,
                    timeSort = "desc"
                )
                
                val response = RetrofitClient.api.getEmailList(token, request)
                
                if (response.isSuccessful && response.body()?.code == 200) {
                    val emails = response.body()?.data ?: emptyList()
                    
                    if (currentPage == 1) {
                        adapter.setEmails(emails)
                    } else {
                        adapter.addEmails(emails)
                    }
                    
                    binding.tvEmpty.visibility = if (adapter.itemCount == 0) View.VISIBLE else View.GONE
                    
                    if (emails.isEmpty() && currentPage > 1) {
                        currentPage-- // No more data
                    }
                } else {
                    val message = response.body()?.message ?: response.errorBody()?.string() ?: "Failed to load emails"
                    Toast.makeText(this@MainActivity, message, Toast.LENGTH_SHORT).show()
                    
                    if (response.code() == 401) {
                        // Token expired, go to login
                        prefs.clear()
                        startActivity(Intent(this@MainActivity, LoginActivity::class.java))
                        finish()
                    }
                }
            } catch (e: Exception) {
                Toast.makeText(this@MainActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                e.printStackTrace()
            } finally {
                isLoading = false
                showLoading(false)
                binding.swipeRefresh.isRefreshing = false
            }
        }
    }
    
    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show && currentPage == 1) View.VISIBLE else View.GONE
    }
}