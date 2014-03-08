require "socket"

class ChatServer
  def initialize(port)
    @sockets = Array.new
    @clients = Array.new
    @rooms = Hash.new

    @server = TCPServer.new("", port)
    puts("Ruby chat server started on port #{port}\n")
    @sockets.push(@server)
    run()
  end

  def run
    while true

      # The select method will take as an argument the array of sockets, and return a socket that has    
      # data to be read
      ioarray = select(@sockets, nil, nil, nil)

        # the socket that returned data will be the first element in this array
        for sock in ioarray[0]
          if sock == @server then
            accept_client
          else
            # Received something on a client socket
            if sock.eof? then
              str = "Client left #{sock.peeraddr[2]}"
              broadcast(str, sock)
              sock.close
              @sockets.delete(sock)
            else
              userinput = sock.gets().chop

              if userinput.split(' ', 2)[0].to_s == "/addroom"
                if !userinput.split(' ', 2)[1].nil?
                  add_room(sock, userinput.split(' ', 2)[1])
                else
                  sock.puts("Plase provide a room name. (no spaces)")
                end

              elsif userinput.split(' ', 2)[0] == "/rooms"
                list_room(sock)

              elsif userinput.split(' ', 2)[0] == "/join"
                if !userinput.split(' ', 2)[1].nil?
                  join_room(sock, userinput.split(' ', 2)[1])
                else
                  sock.puts("Plase provide a room name. (no spaces)")
                end

              elsif userinput.split(' ', 2)[0] == "/leave"
                leave_room(sock, userinput)  

              elsif userinput.split(' ', 2)[0] == "/quit"
                quit(sock)  

              elsif userinput.split(' ', 2)[0] == "/help"
                show_instruction(sock)  

              else
                print(userinput)
                if userinput != ""
                  curr_user = @clients.select{|client| client["socket"] == sock}
                  
                  if curr_user[0]['current_room'] != "" && (@rooms.detect {|roomname, participant| roomname ==  curr_user[0]['current_room']})
                    curr_room = @rooms.select {|roomname, participants| roomname == curr_user[0]['current_room']}
                   
                    #private message in room
                    if userinput.split(' ', 2)[0].match("@")
                      recipient = userinput.split(' ', 2)[0].sub! "@", ""
                      chatinput = userinput.split(' ', 2)[1]

                      recipient_exist = false
                      curr_room[curr_user[0]['current_room']].each_with_index do |participant, index| 
                        str = "[#{curr_user[0]['username']}]: #{userinput}"

                        if participant['username'] == recipient
                          str = "[*private*@#{curr_user[0]['username']}]: #{chatinput}"
                          participant["socket"].puts(str)
                          recipient_exist = true
                        end
                      end

                      if !recipient_exist
                        str = "@#{recipient} does not exist or not in this room"
                        curr_user[0]['socket'].puts(str)
                      end
                    else
                    #public broadcast in room
                      curr_room[curr_user[0]['current_room']].each do |participant| 
                        str = "[#{curr_user[0]['username']}]: #{userinput}"
                        if participant["socket"] != sock
                          participant["socket"].puts(str)
                        end
                      end
                    end
                  end
                end

              end
            end
          end
        end
    end
  end

  def quit(sock)
    socket_index = @sockets.find_index{|socket| socket == sock}
    # close socket
    @sockets[socket_index].close

    #remove from @sockets
    @sockets.delete_if{|socket| socket == sock}

    #remove from @clients
    @clients.delete_if{|client| client['socket'] == sock}
  end

  def leave_room(sock, userinput)
    curr_user_index = @clients.find_index{|client| client["socket"] == sock}
    curr_user_room = @clients[curr_user_index]["current_room"]
    
    # if user currently in a room
    if curr_user_room != ""
      # clear current_room in @client
      @clients[curr_user_index]["current_room"] = ""
      
      # delete participant from @rooms[roomname][{username, socket, current_room}]
      @rooms[curr_user_room].delete_if{|participant| participant['socket'] == sock}

      # broadast to participant in the room
      str = "\"#{@clients[curr_user_index]["username"]}\" has left the room."
      @rooms[curr_user_room].each do |participant|
        participant['socket'].puts(str)
      end

      sock.puts("you left #{curr_user_room}")
    end
  end

  def join_room(sock, roomname)

    if @rooms.include? roomname

      #search user from client array
      curr_user_index = @clients.find_index{|client| client["socket"] == sock}

      # put user information in room joined
      @rooms[roomname].push(@clients[curr_user_index])

      #indicate user is in chatroom
      @clients[curr_user_index]["current_room"] = roomname

      sock.puts("You are now in #{roomname}! Start chatting!")

      sock.puts("***beginning of participant list***")

      #list other participant in the room
      @rooms[roomname].each do |participant|
        str = "* #{participant['username']}"
        if(participant['socket'] == sock)
          str = "* #{participant['username']}(** this is you!)"
        end
          sock.puts(str)
      end

      sock.puts("***end of participant list***")

      #broadcast to other participant in the room
      curr_room = @rooms.select {|roomname, participants| roomname == roomname}
      
      curr_room[roomname].each do |participant| 
        str = "A new user just joined :[#{@clients[curr_user_index]['username']}]"
        if participant["socket"] != sock
          participant["socket"].puts(str)
        end
      end

    else
      sock.puts("\"#{roomname}\" doesn\'t exist, choose another room!")
    end

  end

  def list_room(sock)
    sock.puts("Active rooms are:")
    @rooms.each do |roomname, participants| 
      sock.puts("* #{roomname} (#{participants.length})")
    end
    sock.puts("End of list.")
  end

  def add_room(sock, roomname)
    
    @sockets.each do |client|
      # online user will get to create room
      if client == sock then
        if !@rooms.include? roomname
          if roomname.match(" ")
            client.puts("\"#{roomname}\" room name contains spaces!")
          elsif roomname == ""
            client.puts("room name cannot be empty!")
          else
            @rooms[roomname] = Array.new
            client.puts("\"#{roomname}\" room has been created")
          end
        else
          client.puts("\"#{roomname}\" room exists. Use another name!")
        end
      end
    end
  end

  def accept_client
    newsocket = @server.accept # Accept newsocket's connection request

    # add newsockets to the list of connected sockets
    @sockets.push(newsocket)
    
    # Inform the socket that it has connected, then inform all sockets of the new connection
    newsocket.puts("Welcome to Brandon's Chatty Room! Woohoo")

    begin
      newsocket.puts("Username? (no spaces)")
      username = newsocket.gets().chop
    end while @clients.detect{|client| client["username"] == username} || (username.match(" "))

    @clients.push(Hash["socket"=>newsocket, "username"=>username, "current_room"=>""])

    str = "#{username} joined #{newsocket.peeraddr[2]}\n"
    newsocket.puts("Hi #{username}! How\'re you doing?")
    newsocket.puts("Here's what you can do!")
    show_instruction(newsocket)
  end

  def broadcast(str, omit_sock)
    # Send the string argument to every socket that is not the server,
    # and not the socket the broadcast originated from.
    @sockets.each do |client|
      if client != @server && client != omit_sock then
        client.puts(str)
      end
    end
    # Print all broadcasts to the server's STDOUT
    print(str)
  end

  def show_instruction(sock)
    str = "*** Instruction Manual *** \n"    
    str += "1 ) \"/addroom <room name with no spaces>\" | to create new room \n"    
    str += "2 ) \"/rooms\" | to list all rooms \n"    
    str += "3 ) \"/quit\" | to quit this application \n"    
    str += "4 ) \"/join <roomname>\" | to join a room \n"    
    str += "5 ) \"/leave\" | to leave from a room (Only works when in a room) \n"    
    str += "6 ) \"@<username with no spaces> <message>\" | to talk privately (Only works when in a room) \n"    
    str += "7 ) \"/help\" | to bring up this instruction manual \n"    
    str += "*** End of Instruction Manual ***\n"  

    sock.puts(str)  
  end

end

myChatServer = ChatServer.new(2700)
