package com.cloudmail.app

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cloudmail.app.api.RetrofitClient
import com.cloudmail.app.databinding.ActivityLoginBinding
import com.cloudmail.app.model.LoginRequest
import com.cloudmail.app.utils.SharedPreferencesManager
import kotlinx.coroutines.launch

class LoginActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityLoginBinding
    private lateinit var prefs: SharedPreferencesManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        prefs = SharedPreferencesManager(this)
        
        // Check if already logged in
        if (!prefs.token.isNullOrEmpty()) {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
            return
        }
        
        // Load saved data
        prefs.baseUrl?.let { binding.etBaseUrl.setText(it) }
        prefs.email?.let { binding.etEmail.setText(it) }
        
        binding.btnLogin.setOnClickListener {
            login()
        }
    }
    
    private fun login() {
        val baseUrl = binding.etBaseUrl.text.toString().trim()
        val email = binding.etEmail.text.toString().trim()
        val password = binding.etPassword.text.toString().trim()
        
        if (baseUrl.isEmpty()) {
            binding.tilBaseUrl.error = "Base URL is required"
            return
        }
        
        if (email.isEmpty()) {
            binding.tilEmail.error = "Email is required"
            return
        }
        
        if (password.isEmpty()) {
            binding.tilPassword.error = "Password is required"
            return
        }
        
        showLoading(true)
        
        lifecycleScope.launch {
            try {
                // Update base URL if needed
                if (baseUrl != RetrofitClient.api.toString()) {
                    // Recreate Retrofit instance with new base URL
                }
                
                val response = RetrofitClient.api.generateToken(LoginRequest(email, password))
                
                if (response.isSuccessful && response.body()?.code == 200) {
                    val token = response.body()?.data?.token
                    if (token != null) {
                        prefs.token = token
                        prefs.email = email
                        prefs.baseUrl = baseUrl
                        
                        Toast.makeText(this@LoginActivity, "Login successful", Toast.LENGTH_SHORT).show()
                        startActivity(Intent(this@LoginActivity, MainActivity::class.java))
                        finish()
                    } else {
                        Toast.makeText(this@LoginActivity, "Invalid response", Toast.LENGTH_SHORT).show()
                    }
                } else {
                    val message = response.body()?.message ?: response.errorBody()?.string() ?: "Login failed"
                    Toast.makeText(this@LoginActivity, message, Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@LoginActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                e.printStackTrace()
            } finally {
                showLoading(false)
            }
        }
    }
    
    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show) View.VISIBLE else View.GONE
        binding.btnLogin.isEnabled = !show
        binding.etBaseUrl.isEnabled = !show
        binding.etEmail.isEnabled = !show
        binding.etPassword.isEnabled = !show
    }
}