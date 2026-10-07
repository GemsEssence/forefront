module Forefront
  # "How it works": the one-screen guide for Sales persons. Static, for
  # everyone who is signed in.
  class HelpController < ApplicationController
    skip_after_action :verify_authorized

    def show
    end
  end
end
