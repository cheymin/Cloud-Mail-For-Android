package com.cloudmail.app

import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.cloudmail.app.databinding.ItemEmailBinding
import com.cloudmail.app.model.Email

class EmailAdapter : RecyclerView.Adapter<EmailAdapter.EmailViewHolder>() {
    
    private val emails = mutableListOf<Email>()
    
    fun setEmails(list: List<Email>) {
        emails.clear()
        emails.addAll(list)
        notifyDataSetChanged()
    }
    
    fun addEmails(list: List<Email>) {
        val startPosition = emails.size
        emails.addAll(list)
        notifyItemRangeInserted(startPosition, list.size)
    }
    
    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): EmailViewHolder {
        val binding = ItemEmailBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return EmailViewHolder(binding)
    }
    
    override fun onBindViewHolder(holder: EmailViewHolder, position: Int) {
        holder.bind(emails[position])
    }
    
    override fun getItemCount(): Int = emails.size
    
    class EmailViewHolder(private val binding: ItemEmailBinding) : RecyclerView.ViewHolder(binding.root) {
        
        fun bind(email: Email) {
            binding.apply {
                // Type badge
                tvType.text = if (email.type == 0) "IN" else "OUT"
                val badgeColor = if (email.type == 0) Color.parseColor("#4CAF50") else Color.parseColor("#2196F3")
                tvType.setBackgroundColor(badgeColor)
                
                // Time
                tvTime.text = email.createTime ?: ""
                
                // Subject
                tvSubject.text = email.subject ?: "(No Subject)"
                
                // From
                val from = if (!email.sendName.isNullOrEmpty()) {
                    "${email.sendName} <${email.sendEmail ?: ""}>"
                } else {
                    email.sendEmail ?: ""
                }
                tvFrom.text = from
                
                // To
                val to = if (!email.toName.isNullOrEmpty()) {
                    "${email.toName} <${email.toEmail ?: ""}>"
                } else {
                    email.toEmail ?: ""
                }
                tvTo.text = to
                
                // Preview
                tvPreview.text = email.text ?: email.content?.replace(Regex("<[^>]*>"), "") ?: ""
                
                // Delete status
                tvDelStatus.visibility = if (email.isDel == 1) View.VISIBLE else View.GONE
            }
        }
    }
}