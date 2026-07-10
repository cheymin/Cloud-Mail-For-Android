package com.cloudmail.app

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.cloudmail.app.api.RetrofitClient
import com.cloudmail.app.databinding.ActivityAddUserBinding
import com.cloudmail.app.model.AddUserRequest
import com.cloudmail.app.model.UserInfo
import com.cloudmail.app.utils.SharedPreferencesManager
import kotlinx.coroutines.launch

class AddUserActivity : AppCompatActivity() {
    
    private lateinit var binding: ActivityAddUserBinding
    private lateinit var prefs: SharedPreferencesManager
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAddUserBinding.inflate(layoutInflater)
        setContentView(binding.root)
        
        prefs = SharedPreferencesManager(this)
        
        binding.btnAdd.setOnClickListener {
            addUser()
        }
        
        binding.btnCancel.setOnClickListener {
            finish()
        }
    }
    
    private fun addUser() {
        val email = binding.etEmail.text.toString().trim()
        val password = binding.etPassword.text.toString().trim()
        val roleName = binding.etRoleName.text.toString().trim()
        
        if (email.isEmpty()) {
            binding.tilEmail.error = "Email is required"
            return
        }
        
        showLoading(true)
        
        lifecycleScope.launch {
            try {
                val token = prefs.token ?: ""
                val userInfo = UserInfo(
                    email = email,
                    password = if (password.isNotEmpty()) password else null,
                    roleName = if (roleName.isNotEmpty()) roleName else null
                )
                
                val request = AddUserRequest(list = listOf(userInfo))
                val response = RetrofitClient.api.addUser(token, request)
                
                if (response.isSuccessful && response.body()?.code == 200) {
                    Toast.makeText(this@AddUserActivity, "User added successfully", Toast.LENGTH_SHORT).show()
                    finish()
                } else {
                    val message = response.body()?.message ?: response.errorBody()?.string() ?: "Failed to add user"
                    Toast.makeText(this@AddUserActivity, message, Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                Toast.makeText(this@AddUserActivity, "Error: ${e.message}", Toast.LENGTH_SHORT).show()
                e.printStackTrace()
            } finally {
                showLoading(false)
            }
        }
    }
    
    private fun showLoading(show: Boolean) {
        binding.progressBar.visibility = if (show) View.VISIBLE else View.GONE
        binding.btnAdd.isEnabled = !show
        binding.btnCancel.isEnabled = !show
        binding.etEmail.isEnabled = !show
        binding.etPassword.isEnabled = !show
        binding.etRoleName.isEnabled = !show
    }
}