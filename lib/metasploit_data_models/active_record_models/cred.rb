module MetasploitDataModels::ActiveRecordModels::Cred
  def self.included(base)
    base.class_eval{
      belongs_to :service, :class_name => "Mdm::Service"
      has_many :notes, :dependent => :destroy, :class_name => "Mdm::Note"

      unless defined? PTYPES
        const_def =<<-CONST_DEF 
          PTYPES = {
            "read/write password" => "password_rw",
            "read-only password" => "password_ro",
            "SMB hash" => "smb_hash",
            "SSH private key" => "ssh_key",
            "SSH public key" => "ssh_pubkey"
          }
        CONST_DEF
        eval(const_def)
      end

      eval("KEY_ID_REGEX = /([0-9a-fA-F:]{47})/") unless defined?(KEY_ID_REGEX) # Could be more strict

      def ptype_human
        humanized = PTYPES.select do |k, v|
          v == ptype
        end.keys[0]

        humanized ? humanized : ptype
      end

      # Returns its workspace
      def workspace
        self.service.host.workspace
      end

      # Returns its key id. If this is not an ssh-type key, returns nil.
      def ssh_key_id
        return nil unless self.ptype =~ /^ssh_/
          return nil unless self.proof =~ KEY_ID_REGEX
        $1.downcase # Can't run into NilClass problems.
      end

      # Returns all private keys with matching key ids, including itself
      # If this is not an ssh-type key, always returns an empty array.
      def ssh_private_keys
        return [] unless self.ssh_key_id
        matches = self.class.all(:conditions => ["creds.ptype = ? AND creds.proof ILIKE ?", "ssh_key", "%#{self.ssh_key_id}%"])
        matches.select {|c| c.workspace == self.workspace}
      end

      # Returns all public keys with matching key ids, including itself
      # If this is not an ssh-type key, always returns an empty array.
      def ssh_public_keys
        return [] unless self.ssh_key_id
        matches = self.class.all(:conditions => ["creds.ptype = ? AND creds.proof ILIKE ?", "ssh_pubkey", "%#{self.ssh_key_id}%"])
        matches.select {|c| c.workspace == self.workspace}
      end

      # Returns all keys with matching key ids, including itself
      # If this is not an ssh-type key, always returns an empty array.
      def ssh_keys
        (self.ssh_private_keys | self.ssh_public_keys)
      end

      def ssh_key_matches?(other_cred)
        return false unless other_cred.kind_of? self.class
        return false unless self.ptype == other_cred.ptype
        case self.ptype
        when "ssh_key"
          matches = self.ssh_private_keys
        when "ssh_pubkey"
          matches = self.ssh_public_keys
        else
          false
        end
        matches.include?(self) and matches.include?(other_cred)
      end
    }
  end
end
